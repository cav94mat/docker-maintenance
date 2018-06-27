#!/bin/bash
# This script does nothing but output the stack path and relevant environment info:

echo "STACK: $1"
echo "ENV:"
echo " stat_pull    = $stat_pull"
echo " stat_build   = $stat_build"
echo " stat_scripts = $stat_scripts"
echo " stat_up      = $stat_up"
