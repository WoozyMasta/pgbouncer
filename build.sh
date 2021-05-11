#!/bin/bash

set -euo pipefail

get-latest-tag() {
  local project="$1"

  curl --silent --location \
    "https://api.github.com/repos/$project/releases/latest" | \
  jq -er .tag_name
}

command -v docker >/dev/null 2>&1 && CMT="docker"
command -v podman >/dev/null 2>&1 && CMT="podman"
[ -z "$CMT" ] && { printf '%s\n' 'Container managment tool not found'; exit 1; }
command -v jq >/dev/null 2>&1 || { printf '%s\n' 'Install JQ first'; exit 1; }

PGBOUNCER_TAG=$(get-latest-tag pgbouncer/pgbouncer)
PANDOC_TAG=$(get-latest-tag jgm/pandoc)
EXPORTER_TAG=$(get-latest-tag prometheus-community/pgbouncer_exporter)
declare -a builded=()

for dockerfile in ./Dockerfile.*; do
  if [ -f "$dockerfile" ]; then

    if [ "$dockerfile" != ./Dockerfile.exporter ]; then
      image="${1:-localhost/pgbouncer}"
      postfix="-${dockerfile//*Dockerfile./}"
      version="${PGBOUNCER_TAG//_/.}"; version="${version//pgbouncer.}"
    else
      image="${1:-localhost/pgbouncer}-exporter"
      version="${EXPORTER_TAG//v}"
    fi

    build_tag="$image:$version${postfix:-}"
    build_latest="$image:latest${postfix:-}"

    printf '\n%s\t%s\n\n' 'Build:' "$build_tag"
    $CMT build \
      --tag "$build_tag" \
      --file "$dockerfile" \
      --build-arg "PGBOUNCER_TAG=$PGBOUNCER_TAG" \
      --build-arg "PANDOC_TAG=$PANDOC_TAG" \
      --build-arg "EXPORTER_TAG=${EXPORTER_TAG//v}" .
    $CMT tag "$build_tag" "$build_latest"

    [ "$dockerfile" == ./Dockerfile.cares ] && \
      $CMT tag "$build_tag" "$image:latest"

    if [ "$image" != localhost/pgbouncer ]; then
      $CMT push "$build_tag"
      $CMT push "$build_latest"
      [ "$dockerfile" == ./Dockerfile.cares ] && $CMT push "$image:latest"
    fi

    image_size="$($CMT inspect pgbouncer | jq .[].Size | numfmt --to=iec)"
    builded[${#builded[@]}]="$build_tag $image_size"
    builded[${#builded[@]}]="$build_latest $image_size"
  fi

  unset image postfix version image_size build_tag build_latest
done

printf '\n%s\n' 'Done:'
printf '\t%s\n' "${builded[@]}"
