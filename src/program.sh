IFS=$'\n'

#@const Current machine or container hostname
readonly hostname="$(hostname)"

#@const Docker image to use for forked containers
#       (setted at compile time by make.sh)
readonly fork_image; # ='cav94mat/docker-maintenance'

#@func Prints a string that is supposed to contain the current container ID
get_ctrdata() {    
    # https://stackoverflow.com/questions/20995351/how-can-i-get-docker-linux-container-information-from-within-the-container-itsel
    cat /proc/self/cgroup | grep "cpu:/"
    cat /proc/self/mountinfo # Fallback
}

#@const A string that is supposed to contain the current container ID (see get_ctrdata())
readonly ctrdata="$(get_ctrdata)"

#@const (Debug only) Output file where `$ctrdata` is written to
readonly ctrlog="$HOME/.ctrdata"
is-debug && echo "$ctrdata" >"$ctrlog"

#@func Determine whether the current stack should be forked.
#       If neither `--fork` or `--no-fork` were specified on the command line,
#       the value is determine by checking if this script is being run on a container
#       belonging to the stack.
# @env $PWD, $COMPOSE_FILE: For determining the current stack.
#      $dm_fork: Set through --fork or --no-fork (possible values are empty, '1' or '0').
# @stdout
#      1 : The present stack requires forking, or --fork was specified on the command line.
#      0 : The present stack does not require forking, or --no-fork was specified on the command line. 
get_fork() {
    if [ "$dm_fork" ]; then
        echo "$dm_fork" # Use global preference            
    else
        # Detect if the current container is within the stack running containers
        log --diag "Checking if the stack at $PWD needs forking"
        for c in $(docker-compose ps -qa); do
            if [[ "${#hostname}" -ge 12 && "$c" == "$hostname"* ]] || [[ "$ctrdata" == *"$c"* ]]; then
                log --diag "Matched {$c} with $hostname, $ctrlog"
                echo 1;                
                return;
            fi
        done
        log --diag "The present context ($hostname, $ctrlog) does not seem to be part of the stack."
        echo 0;
    fi
}

#@func Spawn a container for performing the maintenance to the current stack in fork-mode.
#      The container is run with `-d`, so the function returns immediately after starting.
# @env $PWD, $COMPOSE_FILE: For determining the current stack.
#      $DOCKER_SOCK:        The path of the docker.sock file, to be bound as a volume in the forked container.
#                             Setted externally or automatically calculated by docker-cli.lib.sh.
#      $fork_image:         The docker image to use for the forked container.
#      *:                   The current environment, to be forwarded to the forked container.
# @stdout:
#      The forked container ID, to be used to control the container later.
start_fork_ctr() {
    log -I 'Starting forked container...'
    declare -a e_vars
    while IFS= read -r -d $'\0' e; do
        e_vars+=('-e' "$e")
    done < <(env -0)
    docker run \
        "${e_vars[@]}" \
        -e 'ON_START=1' -e 'ON_SCHEDULE=' -e 'SCHEDULE=' \
        -v "$PWD:$PWD" \
        -v "$DOCKER_SOCK:$DOCKER_SOCK" \
        -d "$fork_image" \
        "${dm_opts[@]}" --no-pull --no-sideload --no-build --no-fork --no-recurse \
        "$PWD"
}

#@func Perform the maintenance workflow on a single stack.
# @env $PWD, $COMPOSE_FILE: For determining the current stack.
#      $DM_STACK_DIR, $stack:  Expected to point respectively to "$PWD" and "$PWD/$COMPOSE_FILE".
run_single() { # <stack>
    log -I "Maintenance started: $stack"
    export LOG_TAG="$PWD"
    export DM_FORK="$(get_fork)"
    export DM_PULLED
    export DM_SIDELOADED
    export DM_BUILT
    export DM_FORKED
    export DM_REDEPLOYED
    # 0. <Pre-scripts>
    for script in "${dm_scripts_pre[@]}"; do
        log -I "> Running pre-script:" "$script \'$stack\'"
        dm-run $script "$stack" || {
            local ec="$?"
            if [ "$ec" -eq 20 ]; then
                log -I "Maintenance halted by pre-script $script ($ec)."
                return 0
            elif [ "$ec" -ge 10 ]; then
                log -W "Non-critical status reported by pre-script $script ($ec)"
            else
                log -E "Critical status reported by pre-script $script ($ec)"
                exit 1
            fi
        }
    done
    
    # 1. Pull
    if is-true "$dm_pull"; then
        log -I "Pulling remote images...";
        if dm-run docker-compose pull --ignore-pull-failures; then
            DM_PULLED=1
        else        
            log -W "Error(s) occurred while pulling remote images."
            DM_PULLED=0
        fi
    fi
    # 2. Sideload
    if is-true "$dm_sideload" && [ -r "$DOCKER_SIDELOAD" ]; then
        log -I "Sideloading local images...";
        if dm-run docker load -i "$DOCKER_SIDELOAD"; then
            DM_SIDELOADED=1
        else
            log -W "Error(s) occurred while sideloading local images."
            DM_SIDELOADED=0
        fi
    fi
    # 3. Build
    if is-true "$dm_build"; then
        log -I "Re-building local images...";
        if dm-run docker-compose build --pull --no-cache; then
            DM_BUILT=1
        else
            log -W "Error(s) occurred while re-building local images."
            DM_BUILT=0
        fi
    fi
    
    if is-true "$DM_FORK"; then
        # 4b. Fork-mode
        #    To be run after pulling and sideloading, in order to have an up-to-date docker-maintenance image.
        local fork_ctr="$(start_fork_ctr)"
        DM_FORKED=1
        log -I "-- Attaching to forked container ($fork_ctr) --"        
        docker logs -f "$fork_ctr"            
        log -I "-- Forked container terminated --"        
        docker rm -f "$fork_ctr"
    else
        # 4. <Scripts>
        for script in "${dm_scripts[@]}"; do
            log -I "> Running script:" "$script \'$stack\'"
            dm-run "$script" "$stack" || {
                local ec="$?"
                if [ "$ec" -eq 20 ]; then
                    log -I "Maintenance terminated by script $script ($ec)."
                    return 0
                elif [ "$ec" -ge 10 ]; then
                    log -W "Non-critical status reported by script $script ($ec)"
                else
                    log -E "Critical status reported by script $script ($ec)"
                    return 1
                fi
            }
        done
        # 5. Re-up
        if is-true "$dm_up"; then
             log -I "Re-creating containers (if required)..."; 
            if dm-run docker-compose up -d; then
                DM_REDEPLOYED=1
            else
                log -W "Error(s) occurred while re-creating containers."
                DM_REDEPLOYED=0
            fi
        fi
        # 6. Post-scripts
        for script in "${scripts_post[@]}"; do
            log -I "> Running post-script:" "$script \'$stack\'"
           dm-run "$script" "$stack" || {
                local ec="$?"
                if [ "$ec" -eq 20 ]; then
                    log -I "Maintenance terminated by post-script $script ($ec)."
                    return 0
                elif [ "$ec" -ge 10 ]; then
                    log -W "Non-critical status reported by post-script $script ($ec)"
                else
                    log -E "Critical status reported by post-script $script ($ec)"
                    return 1
                fi
            }
        done
    fi
}

# Main #
MAINTENANCE_LOG="${MAINTENANCE_LOG:-/dev/null}"
MAINTENANCE_LOG_ANSI="${MAINTENANCE_LOG_ANSI:-/dev/null}"

err=0
while [ "$#" -gt 0 ]; do
    if ! { dm-args "$@" && shift $REPLY; } then
        exit 1
    elif [ "$#" -eq 0 ]; then
        log -E 'No paths specified. Try --help for more information.'
        exit 1;
    else
        is-true "$dm_simulated" \
            && log -W 'Dry-run mode. No actual maintenance operations are being performed.'
        #log --diag "find: $1 -maxdepth "$dm_rec" -name $COMPOSE_FILE"
        for dir in $(log --diag --execute find "$1" -maxdepth "$dm_rec" -name "$COMPOSE_FILE" -printf '%h\n'|sort); do
        (            
            cd "$dir"
            export DM_STACK="$dir/$COMPOSE_FILE"
            export DM_STACK_DIR="$PWD" # Force absolute path
            { run_single || err=1; } 2>&1 \
                | tee -a "$MAINTENANCE_LOG_ANSI" | tee '/dev/fd/2' | ansi-strip >> "$MAINTENANCE_LOG"
        )
        done
    fi
    shift;
done

[ "$dm_clean" ] || { log -I "Cleaning up..."; dm-run docker system prune $dm_clean; } \
    || log -W "Error(s) occurred while performing Docker cleanup."

exit "$err";
