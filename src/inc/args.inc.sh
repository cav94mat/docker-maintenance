#!/bin/bash

#@var (UInt) Maximum recursion depth
export dm_rec=1
#@var (Bool) Whether images should be pulled
export dm_pull=1
#@var (Bool) Whether local images should be re/built
export dm_build=1
#@var (Bool) Whether local image tar(s) should be sideloaded
export dm_sideload=1
#@var (Bool) Whether stacks should be re-started
export dm_up=1
#@var (String) If set, mode for the final pruning (-af or -f)
export dm_clean=
#@var (Bool) Whether simulated execution is enabled (--dry-run)
export dm_simulated=
#@var (Bool?) Whether form mode is enabled or disabled globally (--fork, --no-fork)
export dm_fork=
#@var (String) The current container ID
export dm_fork_host=

#@var (Array) Scripts to run before the maintenance of each stack
declare -ax dm_scripts_pre
#@var (Array) Scripts to run during the maintenance of each stack
declare -ax dm_scripts
#@var (Array) Scripts to run after the maintenance of each stack
declare -ax dm_scripts_post
#@var (Array) Array of the options to be passed to forked containers
declare -ax dm_opts

#@func Print the program name and version to the standard output.
# @stdoud Program name and build number/version.
dm-version() {
    echo "$(basename "$0") ($build)"
}
#@func Print the usage information to the standard output.
# @stdout The usage information.
dm-help() {
    dm-version
    echo ''
    echo 'USAGE:'
    echo ''
    echo "$0 [<<params>>] <<dirs>>"
    echo
    echo 'OPTIONS:'
    echo ''
    echo '  --dry, --dry-run    Dry run (does nothing, only logging)'
    echo '  --help              Print this help screen and exit'
    echo '  --version           Print the version number and exit'
    echo ''
    echo '  --auto-auto         Enforce spawning a new forked maintenance container only if required (default)'
    echo '  --fork              Enforce spawning a new forked maintenance container'    
    echo '  --no-fork           Prevent spawning a new forked maintenance container'
    echo ''
    echo '  --no-recurse        Disable recursion (default)'
    echo '  --recurse           Recursively search for stacks in subdirectories'
    echo '  --recurse-one       Search for stacks in the first level of subdirectories'    
    echo ''
    echo 'WORKFLOW MODIFIERS:'
    echo ''
    echo '  --run-pre <file>    Specify the pre-maintenance script(s)';
    echo ''
    echo '  --pull              Enable pulling images from the registry (default)'
    echo '  --no-pull           Disable pulling images from the registry'
    echo ''
    echo '  --sideload          Enable sideloading images from local archives (default)'
    echo '  --no-sideload       Disable sideloading images from local archives'
    echo ''
    echo '  --build             Enable building images whose sources are defined in the stack (default)'
    echo '  --no-build          Disable building images whose sources are defined in the stack'
    echo ''
    echo '  --up                Enable recreating and restarting affected containers (default)'
    echo '  --no-up             Disable recreating and restarting affected containers'
    echo '  --run <file>        Specify the maintenance script(s)';
    echo ''
    echo '  --run-post <file> Specify the post-maintenance script(s)';
    echo ''    
    echo '  --clean           Run `docker system prune -af` at the end' 
    echo '  --clean-dangling  Run `docker system prune -f` at the end'
    echo '  --no-clean        Do not run any `docker system prune` operation at the end (default)'
    echo ''
    echo 'ENVIRONMENT':
    echo ''
    echo '  COMPOSE_BIN:      Command to run for `docker-compose`'
    echo '  COMPOSE_FILE:     Name of the stack file (`docker-compose.yml`)'
    echo '  DEBUG:            If set, it enables debug logging'
    echo '  DOCKER_BIN:       Command to run for `docker`'    
    echo '  DOCKER_SIDELOAD:  Name of the sideload file(`docker-sideload.tar`)'
    echo '  MAINTENANCE_LOG:  Name for the log file, relative to specified path(s).'
    echo ''
    echo ' * Options `--run`, `--run-pre`, `--run-post` can be specified multiple times.'
    echo ' * Options specified last override the behavior of preceding ones, e.g:'
    echo '   `--fork --no-fork` results in `--no-fork` taking over.'
}

#@func Read options from the environment.
# @env-out $dm_rec, $dm_pull, $dm_build, $dm_sideload, $dm_up, $dm_clean, dm_simulated,
#          $dm_fork, dm_scripts_pre, dm_scripts_post, $dm_opts
# @reply   ($REPLY) Number of arguments processed (to shift)
# @exit    0: Options parsed correctly, or no option to parse,
#          1: Unsupported option specified, or bad value for an option.
dm-env() {
    # Determine the current container ID.
    #  https://stackoverflow.com/questions/20995351/how-can-i-get-docker-linux-container-information-from-within-the-container-itsel
    local ctrdata="$(cat /proc/self/cgroup|grep "cpu:/"; cat /proc/self/mountinfo)"
    local hostname="$(hostname)"
    if [ "$ctrdata" ]; then   
        for c in $(docker ps -qa --no-trunc); do
            if [[ "${#hostname}" -ge 12 && "$c" == "$hostname"* ]] || [[ "$ctrdata" == *"$c"* ]]; then                
                dm_fork_host="$c"
                log --diag "Determined current container ID: $dm_fork_host"
                break;
            fi
        done
    fi
}

#@func Read options from arguments, stopping when the path of a stack is found.
# @syntax [<<options>>]
# @env-out $dm_rec, $dm_pull, $dm_build, $dm_sideload, $dm_up, $dm_clean, dm_simulated,
#          $dm_fork, dm_scripts_pre, dm_scripts_post, $dm_opts
# @reply   ($REPLY) Number of arguments processed (to shift)
# @exit    0: Options parsed correctly, or no option to parse,
#          1: Unsupported option specified, or bad value for an option.
dm-args() {
    local startlen="$#"
    while [ "$#" -gt 0 -a "${1:0:1}" = "-" ]; do
        case "$1" in
            '--recurse')
                dm_rec=2147483647 # Max
                ;;
            '--recurse-one')
                dm_rec=2
                ;;
            '--no-recurse')
                dm_rec=1
                ;;
            '--dry'|'--dry-run')
                dm_simulated=1
                ;;
            '--auto-fork'|'--fork-auto')
                dm_fork=
                ;;
            '--fork')
                dm_fork=1
                ;;
            '--no-fork')
                dm_fork=0
                ;;
            '--run')
                dm_opts+=("$1")
                dm_scripts+=("$2")
                shift 1
                ;;
            '--run-pre')
                dm_opts+=("$1")
                dm_scripts_pre+=("$2")            
                shift 1
                ;;
            '--run-post')
                dm_opts+=("$1")
                dm_scripts_post+=("$2")            
                shift 1
                ;;
            '--pull')
                dm_pull=1
                ;;
            '--no-pull')
                dm_pull=0
                ;;
            '--build')
                dm_build=1
                ;;
            '--no-build')
                dm_build=0
                ;;
            '--sideload')
                dm_sideload=1
                ;;
            '--no-sideload')
                dm_sideload=0
                ;;
            '--up')
                dm_up=1
                ;;
            '--no-up')
                dm_up=0
                ;;
            '--clean')
                dm_clean='-af'
                ;;
            '--clean-dangling')
                dm_clean='-f'
                ;;
            '--no-clean')
                dm_clean=
                ;;
            '--help')
                dm-help
                exit 0
                ;;
            '--version')
                dm-version
                exit 0
                ;;
            *)
                log -E "Illegal option \`$1\`. Try --help for more information."
                return 1;
                ;;
        esac
        dm_opts+=("$1")
        shift
    done
    REPLY="$(($startlen - $#))"
}
export -f dm-args

#@func Execute a command only if $dm_simulated evaluates to false.
# @syntax <command> [<<args>>]
# @env    $dm_simulated
dm-run() {
    if is-false "$dm_simulated"; then
        log --diag --execute "$@"
    else
        log --diag "$@"
    fi
}
export -f dm-run