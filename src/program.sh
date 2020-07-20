IFS=$'\n'  
#@func Print the usage information to the standard output.
# @stdout The usage information.
usage() {
    echo "docker-maintenance ($build)"
    echo ''
    echo 'USAGE:'
    echo ''
    echo "$0 [<<params>>] <<dirs>>"
    echo
    echo 'OPTIONS:'
    echo ''
    echo '  --dry, --dry-run  Dry run (does nothing, only logging)'
    echo '  --fork            Forcefully spawn a new maintenance container.'    
    echo '  --no-fork         Suppress the automatic spawning of a new maintenance container.'    
    echo '  --no-recurse      Suppress recursion (default if no recurse option was specified).'        
    echo '  --recurse         Recursively search for stacks in subdirectories.'
    echo '  --recurse-one     Search for stacks in the first level of subdirectories.'    
    echo ''
    echo 'WORKFLOW MODIFIERS:'
    echo ''
    echo '  --run-pre <file>  Specify the pre-maintenance script(s)';
    echo ''
    echo '  --no-pull         Disable automatic image pull/update'     
    echo '  --no-sideload     Disable automatic image sideloading from ./docker-sideload.tar'
    echo '  --no-build        Disable automatic image re-building'
    echo ''
    echo '  --run <file>      Specify the maintenance script(s).';
    echo '  --no-up           Disable automatic stack re-creation'
    echo ''
    echo '  --run-post <file> Specify the post-maintenance script(s)';
    echo ''
    echo '  --clean           Run `docker system prune -af` at the end' 
    echo '  --clean-dangling  Run `docker system prune -f` at the end'
    echo ''
    echo 'ENVIRONMENT':
    echo ''
    echo '  COMPOSE_BIN:      Command to run for `docker-compose`'
    echo '  COMPOSE_FILE:     Name of the stack file (`docker-compose.yml`)'
    echo '  DEBUG:            If set, it enables debug logging.'
    echo '  DOCKER_BIN:       Command to run for `docker`'    
    echo '  MAINTENANCE_LOG:  Name for the log file, relative to specified paths'
    echo '                    (default to `./.last-maintenance.log`)'
    echo ''
    echo ' * Options `--run`, `--run-pre`, `--run-post` can be specified multiple times.'
    echo ' * Options specified last override the behavior of preceding ones, e.g:'
    echo '   `--fork --no-fork` results in `--no-fork` taking over.'
}

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
[ "$DEBUG" ] && echo "$ctrdata" >"$ctrlog"
#@const Docker socket file to forward to forked containers.
fork_sock='/var/run/docker.sock'
[[ "$DOCKER_HOST" == "unix://"* ]] && fork_sock="${DOCKER_HOST:7}"
readonly fork_sock;

#@func Determine whether the current stack should be forked.
#       If neither `--fork` or `--no-fork` were specified on the command line,
#       the value is determine by checking if this script is being run on a container
#       belonging to the stack.
# @env $PWD, $COMPOSE_FILE: For determining the current stack.
#      $g_fork: Set through --fork or --no-fork (possible values are empty, '1' or '0').
# @stdout
#      1 : The present stack requires forking, or --fork was specified on the command line.
#      0 : The present stack does not require forking, or --no-fork was specified on the command line. 
get_fork() {
    if [ "$g_fork" ]; then
        echo "$g_fork" # Use global preference            
    else
        # Detect if the current container is within the stack running containers
        log --diag "Checking if the stack at $PWD needs forking"
        for c in $(dryrun= docker-compose ps -qa); do            
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
#      $fork_sock:          The path of the docker.sock file, to be bound as a volume in the forked container.
#      $fork_image:         The docker image to use for the forked container.
#      *:                   The current environment, to be forwarded to the forked container.
# @stdout:
#      The forked container ID, to be used to control the container later.
start_fork_ctr() {
    log -I 'Starting forked container...'
    declare -a e_vars
    for e in $(env); do
        e_vars+=('-e' "$e")
    done
    dryrun= docker run \
        "${e_vars[@]}" \
        -e 'ON_START=1' -e 'ON_SCHEDULE=' -e 'SCHEDULE=' \
        -v "$PWD:$PWD" \
        -v "$fork_sock:$fork_sock" \
        -d "$fork_image" \
        "${g_opts[@]}" --no-pull --no-sideload --no-build --no-fork --no-recurse \
        "$PWD"
}

#@func Perform the maintenance workflow on a single stack.
# @env $PWD, $COMPOSE_FILE: For determining the current stack.
#      $stack_dir, $stack:  Expected to point respectively to "$PWD" and "$PWD/$COMPOSE_FILE".
run_single() { # <stack>
    cd "$stack_dir"
    (    
        log -I "Maintenance started: $stack"
        export LOG_TAG="$PWD"
        export fork="$(get_fork)"
        
        # 0. <Pre-scripts>
        for script in "${scripts_pre[@]}"; do
            log -I "> Running pre-script:" "$script \'$stack\'"
            [ "$dryrun" ] || "$script" "$stack" || {
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
        export stat_pull=1
        [ "$no_pull" ] || { log -I "Pulling images..."; docker-compose pull --ignore-pull-failures; } \
            || {
                log -W "Error(s) occurred while pulling updated images."
                stat_pull=0
            }
        # 2. Sideload
        export stat_sideload=1
        [ "$no_sideload" -o ! -r './docker-sideload.tar' ] || { log -I "Sideloading local images..."; docker load -i './docker-sideload.tar'; } \
            || {
                log -W "Error(s) occurred while sideloading local images."
                stat_sideload=0
            }   
        # 3. Build
        export stat_build=1
        [ "$no_build" ] || { log -I "Re-building local images..."; docker-compose build --pull --no-cache; } \
        || {
            log -W "Error(s) occurred while re-building local images."
            stat_build=0
        }      
        if [ "$fork" = '1' ]; then
            # 4b. Fork-mode
            #    To be run after pulling and sideloading, in order to have an up-to-date docker-maintenance image.
            local fork_ctr="$(start_fork_ctr)"
            export stat_fork=1
            log -I "-- Attaching to forked container ($fork_ctr) --"
            dryrun= \
                docker logs -f "$fork_ctr"            
            log -I "-- Forked container terminated --"
            dryrun= \
                docker rm -f "$fork_ctr"
        else
            # 4. <Scripts>
            for script in "${scripts[@]}"; do
                log -I "> Running script:" "$script \'$stack\'"
                [ "$dryrun" ] || "$script" "$stack" || {
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
            export stat_up=1
            [ "$no_up" ] || { log -I "Re-creating containers (if required)..."; docker-compose up -d; } \
                || {
                    log -W "Error(s) occurred while re-creating containers."
                    stat_up=0
                }
            # 6. Post-scripts
            for script in "${scripts_post[@]}"; do
                log -I "> Running post-script:" "$script \'$stack\'"
                [ "$dryrun" ] || "$script" "$stack" || {
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
    )
}

# Main #
MAINTENANCE_LOG="${MAINTENANCE_LOG:-/dev/null}"
MAINTENANCE_LOG_ANSI="${MAINTENANCE_LOG_ANSI:-/dev/null}"
maxdepth=1
no_pull=
no_build=
no_sideload=
no_up=
no_clean=1
no_adv_clean=
dryrun=
g_fork=
declare -a scripts
declare -a scripts_pre
declare -a scripts_post
declare -a g_opts
while [ "$#" -gt 0 -a "${1:0:1}" = "-" ]; do
    case "$1" in
        "--recurse")
            maxdepth=2147483647 # Max
            ;;
        "--recurse-one")
            maxdepth=2
            ;;
        "--no-recurse")
            maxdepth=1
            ;;
        "--dry"|"--dry-run")
            dryrun=1
            ;;
        "--fork")
            g_fork=1
            ;;
        "--no-fork")
            g_fork=0
            ;;        
        "--run")
            scripts+=("$2")
            shift 1
            ;;
        "--run-pre")
            scripts_pre+=("$2")
            shift 1
            ;;
        "--run-post")
            scripts_post+=("$2")
            shift 1
            ;;
        "--no-pull")
            no_pull=1
            ;;
        "--no-build")
            no_build=1
            ;;
        "--no-sideload")
            no_sideload=1
            ;;
        "--no-up")
            no_up=1
            ;;
        "--clean")
            no_clean=
            ;;
        "--clean-dangling")
            no_adv_clean=1
            ;;
        "--help")
            usage >&2
            exit 0;
            ;;
        *)
            log -E "Illegal option \`$1\`. Try --help for more information."
            exit 1;
            ;;
    esac
    g_opts+=("$1")
    shift
done

[ "$#" -gt 0 ] || {
    log -E 'No paths specified. Try --help for more information.'
}

[ "$dryrun" ] && log -W 'Dry-run mode. No actual maintenance operations are being performed.'

err=0
while [ "$#" -gt 0 ]; do
    log --diag "find: $1 -maxdepth $maxdepth -name $COMPOSE_FILE"
    for stack_dir in $(find "$1" -maxdepth $maxdepth -name "$COMPOSE_FILE" -printf '%h\n'|sort); do
        export stack_dir
        export stack="$stack_dir/$COMPOSE_FILE"
        log --diag "-> $stack"
        cd "$stack_dir"
        { run_single || err=1; } 2>&1 \
            | tee -a "$MAINTENANCE_LOG_ANSI" | tee '/dev/fd/2' | ansi_strip >> "$MAINTENANCE_LOG"
    done
    shift;
done

clean_mode="-af"
[ "$no_adv_clean" ] && clean_mode="-f"
[ "$no_clean" ] || { log -I "Cleaning up..."; docker system prune "$clean_mode"; } \
    || log -W "Error(s) occurred while cleaning up Docker storage."
exit "$err";
