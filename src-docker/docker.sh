#!/bin/bash

# 1. Perform maintenance on startup, or continue pending maintenance
/usr/bin/docker-maintenance "$@" || exit $?;

if [ "$SCHEDULE" ]; then    
  {
    printf '%s /usr/bin/docker-maintenance ' "$SCHEDULE"
    while [ "$#" -gt 0 ]; do
        printf '%q ' "$1"
        shift
    done
    printf '\n'
  } >/etc/crontabs/root  
  echo "-- Scheduled maintenance --"
  echo "Current time : $(date)"
  echo "Cron job ... : $(crontab -l)"
  echo ""
  exec crond -f -d 8
fi