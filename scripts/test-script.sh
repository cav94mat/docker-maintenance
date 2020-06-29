#!/bin/bash
# This script does nothing but output the stack path and relevant environment info:

echo "STACK: $1" # Points to the docker-compose.yml file
echo "PWD: $PWD" # Points to the docker-compose.yml parent directory ($dirname $1)

# Phases
# = '1' if completed, = '' if completed partially, <undefined> if not yet started.
echo " stat_pull     = $stat_pull"
echo " stat_sideload = $stat_sideload"
echo " stat_build    = $stat_build"
echo " stat_scripts  = $stat_scripts"
echo " stat_up       = $stat_up"

# <!> Do never `down` or `stop` the entire stack, if you're running the maintenance
#     from a `cav94mat/docker-maintenance` service defined in  the stack itself.
#
#     Always stop single services:
#
# docker-compose stop <service>