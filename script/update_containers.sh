#!/usr/bin/env bash

set -e -u

SCRIPT_NAME=$(basename "$0")

HELP=$(cat <<EOH
Usage: $SCRIPT_NAME <prod|beta|test> [on <hosts list>]"

Update MusicBrainz website/webservice containers on specified hosts.
If no (space-delimited) hosts list is specified, update on all hosts.
EOH
)

MB_SERVER_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../" && pwd)

cd "$MB_SERVER_ROOT"

if [ $# -eq 0 ]
then
  echo >&2 "$SCRIPT_NAME: missing arguments"
  echo >&2 "$HELP"
  exit 64
elif echo "$1" | grep -Eqvx 'prod|beta|test'
then
  echo >&2 "$SCRIPT_NAME: unrecognized argument: $1"
  echo >&2 "$HELP"
  exit 64
fi

DEPLOY_ENV=$1
shift

SERVICES="musicbrainz-webservice musicbrainz-website"

if [ $# -eq 0 ]
then
  LIST_METABRAINZ_HOSTS=${LIST_METABRAINZ_HOSTS:-../docker-server-configs/scripts/list_nodes.sh}
  if ! type "$LIST_METABRAINZ_HOSTS" >/dev/null
  then
    sed -E 's/^ *> ?//' >&2 << ....EOM
    > $SCRIPT_NAME: cannot list hosts per service/deploy env
    >
    > Please set \$LIST_METABRAINZ_HOSTS or specify hosts list
....EOM
    exit 69
  fi

  HOSTS=$(
    for service in $SERVICES
    do
      "$LIST_METABRAINZ_HOSTS" "$service" "$DEPLOY_ENV"
    done | sort -u
  )
else
  if [ "$1" != 'on' ]
  then
    echo >&2 "$SCRIPT_NAME: missing 'on' separator"
    echo >&2 "$HELP"
    exit 64
  elif [ $# -eq 1 ]
  then
    echo >&2 "$SCRIPT_NAME: missing (space-separated) hosts list"
    echo >&2 "$HELP"
    exit 64
  fi

  shift
  HOSTS="$*"
fi

for host in $HOSTS
do
  echo "$host: Updating containers..."
  ssh "$host" sudo -H -S -- bash -e -u -x <<< $(sed -E 's/^ *; ?//' << ..EOSSH
  ; cd /root/docker-server-configs
  ; git pull
  ; for service in $SERVICES
  ; do
  ;   container=\$service-$DEPLOY_ENV
  ;   if docker container inspect \$container &>/dev/null
  ;   then
  ;     docker stop --time 30 \$container && docker rm \$container
  ;   fi
  ; done
  ; ./scripts/start_services.sh || exit 0
..EOSSH
  )
  sleep 30
done

# vi: set et sts=2 sw=2 ts=2 :
