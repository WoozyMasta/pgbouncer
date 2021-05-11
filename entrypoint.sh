#!/bin/bash

set -euo pipefail
cmd=$(basename "$0")

# PostgreSQL connection params
: "${POSTGRES_HOST:?Plase set PostgreSQL address}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_PASSWORD:=postgres}"
: "${POSTGRES_DB:=postgres}"
export PGPASSWORD="$POSTGRES_PASSWORD"

# PostgreSQL binary with params
psql_opt=(
  psql
  --username="$POSTGRES_USER"
  --host="$POSTGRES_HOST"
  --port="$POSTGRES_PORT"
  --tuples-only
  --dbname="$POSTGRES_DB"
)

# PgBouncer configuration paths
: "${PGBOUNCER_BASE_CONFIG_FILE:=/pgbouncer/share/doc/pgbouncer/pgbouncer.ini}"
: "${PGBOUNCER_CONFIG_FILE:=/pgbouncer/etc/pgbouncer.ini}"

# Default PgBouncer params
: "${PGBOUNCER_LISTEN_ADDR:=*}"
: "${PGBOUNCER_LISTEN_PORT:=5432}"
: "${PGBOUNCER_LOGFILE:=/dev/null}"
: "${PGBOUNCER_PIDFILE:=/pgbouncer/pgbouncer.pid}"
: "${PGBOUNCER_AUTH_TYPE:=md5}"
: "${PGBOUNCER_AUTH_FILE:=/pgbouncer/etc/userlist.txt}"
: "${PGBOUNCER_ADMIN_USERS:=$POSTGRES_USER}"
# Tweak PgBouncer params
: "${PGBOUNCER_POOL_MODE:=transaction}"
: "${PGBOUNCER_IGNORE_STARTUP_PARAMETERS:=extra_float_digits}"
: "${PGBOUNCER_SERVER_CHECK_QUERY:=SELECT 1}"
: "${PGBOUNCER_SERVER_CHECK_DELAY:=30}"
: "${PGBOUNCER_STATS_PERIOD:=60}"
: "${PGBOUNCER_MAX_CLIENT_CONN:=500}"
: "${PGBOUNCER_DEFAULT_POOL_SIZE:=50}"
: "${PGBOUNCER_RESERVE_POOL_SIZE:=25}"

# Background job to update userlist or auth_query
: "${PGBOUNCER_BACKGROUND_CHECK_ENABLED:=true}"
: "${PGBOUNCER_BACKGROUND_CHECK_FREQUENCY:=${PGBOUNCER_STATS_PERIOD:-60}}"

# Default auth query
# shellcheck disable=SC2016
_default_auth_query='SELECT usename, passwd FROM pg_shadow WHERE usename=$1'

# Set auth mode
if [ "$PGBOUNCER_AUTH_TYPE" == md5 ] || [ "$PGBOUNCER_AUTH_TYPE" == hba ]; then
  : "${PGBOUNCER_MODE:=query}" # query, userlist, none
  if [ "$PGBOUNCER_MODE" == query ]; then
    : "${PGBOUNCER_AUTH_QUERY:=$_default_auth_query}"
  else
    unset PGBOUNCER_AUTH_QUERY
  fi
else
  PGBOUNCER_MODE=none
fi

# Formated date for log messages
datef() { date '+%F %T.%3N %Z'; }

# Log messages
fail() { >&2 printf "$(datef) [$$ $cmd] ERROR %s\n" "$*"; exit 1; }
warn() { printf "$(datef) [$$ $cmd] WARNING %s\n" "$*"; }
info() { >&3 printf "$(datef) [$$ $cmd] INFO %s\n" "$*"; }
infof() { >&3 printf "$(datef) [$$ $cmd] INFO %s - " "$*"; }

# Check file not exist and can write
#   Args:
#     file path
#   Return:
#     0 - if not exist and writable
#     1 - if exist
check-file() {
  local file="$1"

  if [ ! -f "$file" ]; then
    if touch "$file"; then
      info "File '$file' exists and is ready to edit"
    else
      fail "File '$file' is not writable, prepare it and mount it as a volume"
    fi
  else
    return 1
  fi
}

# Update only exists (comented or defined) params in ini file in one specified
# section. Param recived from environment variable name defined after prefix,
# value recive from value of variable.
#   Args:
#     ini section
#     file path
write-pgbouncer-config() {
  local section="$1" file="$2"

  info "Set [$section] params from environment variables:"
  for var in ${!PGBOUNCER_@}; do
    if [ -n "$var" ]; then
      k=${var##PGBOUNCER_}; k=${k,,}
      v=${!var}
      info "$k='$v'"
      sed \
        -r "/^\[$section]/,/^\[/{s/^;?$k\s*?=.*$/$k = ${v//\//\\/}/}" \
        -i "$file"
      unset k v
    fi
  done
}

# Print PostgreSQL username and md5 hash
#   Args:
#     username (PostgreSQL username)
#     password (PostgreSQL user password)
#   Return: "username" "md55a231fcdb710d73268c4f44283487ba2"
md5-pass() {
  local user="$1" pass="$2"

  printf '"%s" "md5%s"\n' \
    "$user" "$(printf '%s' "$pass$user" | md5sum | awk '{print $1}')"
}

# Write all PostgreSQL usernames and md5 hashes to file,
# or for one specified user
#   Args:
#     file path
#     username (optional)
write-pgbouncer-userlist() {
  local file="$1" user="${2:-}"

    info "Write all PostgreSQL usernames and md5 hashes to file '$1'"
    if [ -n "${user:-}" ]; then
      "${psql_opt[@]}" --command="
        SELECT concat('\"', usename, '\" \"', passwd, '\"')
        FROM pg_shadow
        WHERE usename = '$user';" | \
      sed 's|^\s?*||' > "$file"
    else
      "${psql_opt[@]}" --command="
        SELECT concat('\"', usename, '\" \"', passwd, '\"')
        FROM pg_shadow;" | \
      sed 's|^\s?*||' > "$file"
    fi
}

# Get all not template databases from PostgreSQL and create function
# for lookup users from pg_shadow, revoke execution rights for all and
# grant execution for specified user, for each databases
#   Args:
#     username
setup-auth-query() {
  local user="$1"

  info "Get list of all databases from $POSTGRES_HOST:$POSTGRES_PORT"
  mapfile -t databases < <(
    "${psql_opt[@]}" --command='
      SELECT datname
      FROM pg_database
      WHERE datistemplate = false;' | \
    sed 's|^\s?*||'
  )

  for db in "${databases[@]}"; do
    if [ -n "$db" ]; then
      infof "Update function to lookup users in $db database"
      "${psql_opt[@]}" --command="
        CREATE OR REPLACE FUNCTION public.lookup (
          INOUT p_user     name,
          OUT   p_password text
        ) RETURNS record
          LANGUAGE sql SECURITY DEFINER SET search_path = pg_catalog AS
        \$\$SELECT usename, passwd FROM pg_shadow WHERE usename = p_user\$\$;
        REVOKE EXECUTE ON FUNCTION public.lookup(name) FROM PUBLIC;
        GRANT EXECUTE ON FUNCTION public.lookup(name) TO $user;"
    fi
  done
}

# Reload PgBouncer configuration
reload-pgbouncer() {
  infof "PgBouncer 0.0.0.0:$PGBOUNCER_LISTEN_PORT configuration reloaded"
  psql \
    --username="$POSTGRES_USER" \
    --host='0.0.0.0' \
    --port="$PGBOUNCER_LISTEN_PORT" \
    --dbname='pgbouncer' \
    --command='RELOAD;'
}


# Print INFO logs when enabled
if [ "${ENTRYPOINT_LOGS_ENABLED:-true}" == 'true' ]; then
  exec 3>&1
else
  exec 3>/dev/null
fi

# Check PostgreSQL connection
info "Check connection to PostgreSQL $POSTGRES_HOST:$POSTGRES_PORT server"
"${psql_opt[@]}" --command='SELECT 1'

# Check PgBouncer config exist and writable
if check-file "$PGBOUNCER_CONFIG_FILE"; then
  # Create PgBouncer config from sample
  cat "$PGBOUNCER_BASE_CONFIG_FILE" > "$PGBOUNCER_CONFIG_FILE"
  # Write config
  write-pgbouncer-config pgbouncer "$PGBOUNCER_CONFIG_FILE"

  # Set databse connection params
  _args="host=$POSTGRES_HOST port=$POSTGRES_PORT"
  [ "$PGBOUNCER_MODE" == query ] && _args="$_args auth_user=$POSTGRES_USER"

  # Write wildcard databse connection
  sed "s|^\[databases\]|[databases]\n* = $_args|" -i "$PGBOUNCER_CONFIG_FILE"
fi

# If PGBOUNCER_MODE in managed state and userlist file writable
if [ "$PGBOUNCER_MODE" != none ] && check-file "$PGBOUNCER_AUTH_FILE"; then

  # Write single user to userlist and create function for all databases
  if [ "$PGBOUNCER_MODE" == query ]; then
    write-pgbouncer-userlist "$PGBOUNCER_AUTH_FILE" "$POSTGRES_USER"
    setup-auth-query "$POSTGRES_USER"

    # Run background check job if enabled
    if [ "$PGBOUNCER_BACKGROUND_CHECK_ENABLED" == true ]; then
      cmd='background'
      while : ;do
        sleep "$PGBOUNCER_BACKGROUND_CHECK_FREQUENCY"s
        setup-auth-query "$POSTGRES_USER"
      done &
    fi

  # Write all users to userlist
  elif [ "$PGBOUNCER_MODE" == userlist ]; then
    write-pgbouncer-userlist "$PGBOUNCER_AUTH_FILE"

    # Run background check job if enabled
    if [ "$PGBOUNCER_BACKGROUND_CHECK_ENABLED" == true ]; then
      cmd='background'
      # Remember curent md5 sum of usserlist file
      _sum="$(md5sum "$PGBOUNCER_AUTH_FILE" | cut -d ' ' -f 1)"

      while : ;do
        sleep "$PGBOUNCER_BACKGROUND_CHECK_FREQUENCY"s
        write-pgbouncer-userlist "$PGBOUNCER_AUTH_FILE"
        # Check new md5 sum of usserlist file and
        # reload PgBouncer if sum not equal
        _new_sum="$(md5sum "$PGBOUNCER_AUTH_FILE" | cut -d ' ' -f 1)"
        if [ "$_sum" != "$_new_sum" ]; then
          reload-pgbouncer
          _sum="$_new_sum"
        fi
      done &
    fi
  fi

fi

# Execute PgBouncer as main PID
exec -a pgbouncer \
  /pgbouncer/bin/pgbouncer --user=pgbouncer "$PGBOUNCER_CONFIG_FILE"
