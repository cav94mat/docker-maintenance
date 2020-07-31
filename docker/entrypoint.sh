#!/bin/bash
cd "$(dirname "$0")"
source '../src/libs/vars.lib.sh'
source '../src/libs/logging.lib.sh'

ON_SCHEDULE="${ON_SCHEDULE:-${SCHEDULE}}"
[ "$ON_SCHEDULE" ] || ON_START=1
log -D "ON_START: $ON_START"
log -D "ON_SCHEDULE: $ON_SCHEDULE"

# 1. Perform maintenance on startup, if requested
[ "${ON_START:-0}" = '0' ] || /usr/bin/docker-maintenance "$@" || exit $?;

# 2. Scheduled maintenance
IFS=$'\n'

if [ "$ON_SCHEDULE" ]; then
  {
    printf '%s /usr/bin/docker-maintenance ' "$ON_SCHEDULE"
    while [ "$#" -gt 0 ]; do
        printf '%q ' "$1"
        shift
    done 
    printf '\n'
  } >/etc/crontabs/root  
  log -I "Scheduled maintenance: $(crontab -l)"
  exec crond -f -d8
fi

