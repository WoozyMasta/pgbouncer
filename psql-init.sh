#!/usr/bin/env bash

set -euo pipefail
count=${1:-10}

name() {
  shuf -n2 /usr/share/dict/words | \
  sed -e ':a;N;$!ba;s/\n/_/g' -e "s/'s//g" -e 's/\(.*\)/\L\1/'
}

pass() {
  tr </dev/urandom -dc 'A-Za-z0-9!@#$^&*' | head -c16
}

create() {
  local name="$1" pass="$2"

  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
  CREATE ROLE $name WITH LOGIN INHERIT PASSWORD '$pass';
  CREATE DATABASE $name WITH OWNER $name;
EOSQL
}

: > ./.credentials
printf '%-5s %-30s %s\n\n' '#' 'DB/User' 'Password'

for i in $(seq 1 "$count"); do
  name="$(name)"; pass="$(pass)"
  printf '%-5s %-30s %s\n' "$i" "$name" "$pass"
  printf '%s='\''%s'\''\n' "$(name)" "$(pass)" >> ./.credentials
done

exit 0
