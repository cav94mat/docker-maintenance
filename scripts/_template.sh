#!/bin/dm-bash

# This script does nothing except logging significant environment values.

log -d "DM_STACK      = $DM_STACK"          # Points to the docker-compose.yml file
log -d "DM_STACK_DIR  = $DM_STACK_DIR"      # Points to the docker-compose.yml parent directory ($dirname $1)

# Phases
#   The value of each step is:
#   '1' if the it completed successfully,
#   '0' if errors occurred,
#   ''  if it was skipped.

log -D "DM_PULLED     = $DM_PULLED"         # Images pulled (--pull)
log -D "DM_SIDELOADED = $DM_SIDELOADED"     # Images sideloaded (--sideload)
log -D "DM_BUILT      = $DM_BUILT"          # Images rebuilt (--build)
log -D "DM_REDEPLOYED = $DM_REDEPLOYED"     # Stack re-deployed (--up)

# Exit codes
#  0:       Successful
#  1 ~ 9:   Hard failure - abort maintenance operations for the current stack,
#  20:      Cancellation request - abort maintenance operations for the current stack, without reporting error(s),
#  *:       Soft failure - continue with the next script or maintenance phase.
exit 0