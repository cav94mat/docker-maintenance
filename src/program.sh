usage() {
    echo "docker-maintenance ($build)"
    echo ""
    echo "USAGE:"
    echo ""
    echo "$0 [<<params>>] <<dirs>>"
    echo
    echo "OPTIONS:"
    echo ""
    echo "  --recurse         Recursively search for docker-compose files."
    echo "  --recurse-one     Search for docker-compose files in first level sub-dirs."
    echo "  --dry             Dry run (does nothing, only logging)"
    echo ""
    echo "  --no-pull         Disable automatic image pull/update"
    echo "  --no-sideload     Disable automatic image sideloading from ./docker-sideload.tar"
    echo "  --no-build        Disable automatic image re-building"
    echo "  --no-up           Disable automatic stack re-creation"
    echo "  --clean           Run \`docker system prune -af\` at the end" 
    echo "  --clean-dangling  Run \`docker system prune -f\` at the end" 
    echo ""
    echo "  --run <file>      Specify maintenance script(s)";
    echo "  --run-pre <file>  Specify the pre-maintenance script(s)";
    echo "  --run-post <file> Specify the post-maintenance script(s)";
}

run_single() { # <stack>
    log --diag "run_single: $1"
    local dir="$(dirname "$1")"
    (    
        log -I "Maintenance started: $1"
        cd "$dir"
        export LOG_TAG="$PWD"
        # 0. <Pre-scripts>
        for script in "${scripts_pre[@]}"; do
            log -I "> Running pre-script:" "$script \'$1\'"
            [ "$dryrun" ] || "$script" "$1" || {
                local ec="$?"
                if [ "$ec" -eq 20 ]; then
                    log -I "Early termination requested by pre-script $script ($ec)."
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
        [ "$no_pull" ] || { log -I "Pulling images..."; _docker_compose pull --ignore-pull-failures; } \
            || {
                log -W "Error(s) occurred while pulling updated images."
                stat_pull=0
            }
        # 2. Sideload
        export stat_sideload=1
        [ "$no_sideload" -o ! -r './docker-sideload.tar' ] || { log -I "Sideloading local images..."; _docker load -i './docker-sideload.tar'; } \
            || {
                log -W "Error(s) occurred while sideloading local images."
                stat_sideload=0
            } 
        # 3. Build
        export stat_build=1
        [ "$no_build" ] || { log -I "Re-building local images..."; _docker_compose build --pull --no-cache; } \
            || {
                log -W "Error(s) occurred while re-building local images."
                stat_build=0
            }
        # 4. <Scripts>
        for script in "${scripts[@]}"; do
            log -I "> Running script:" "$script \'$1\'"
            [ "$dryrun" ] || "$script" "$1" || {
                local ec="$?"
                if [ "$ec" -eq 20 ]; then
                    log -I "Early termination requested by script $script ($ec)."
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
        [ "$no_up" ] || { log -I "Re-creating containers (if required)..."; _docker_compose up -d; } \
            || {
                log -W "Error(s) occurred while re-creating containers."
                stat_up=0
            }
        # 6. Post-scripts
        for script in "${scripts_post[@]}"; do
            log -I "> Running post-script:" "$script \'$1\'"
            [ "$dryrun" ] || "$script" "$1" || {
                local ec="$?"
                if [ "$ec" -ge 10 ]; then
                    log -W "Non-critical status reported by post-script $script ($ec)"
                else
                    log -E "Critical status reported by post-script $script ($ec)"
                    return 1
                fi
            }
        done
     ) 2>&1 | tee "$dir/$MAINTENANCE_LOG" 
}
run() {
    local maxdepth;
    local err=0;
    case "$rec" in
        "all")
            maxdepth=2147483647; # 2^32-1
            ;;
        "1")
            maxdepth=2
            ;;
        "")
            maxdepth=1
            ;;
    esac
    while [ "$#" -gt 0 ]; do
        log --diag "find: $1 -maxdepth $maxdepth -name $COMPOSE_FILE"
        for i in $(find "$1" -maxdepth $maxdepth -name "$COMPOSE_FILE" -printf '%h\n'|sort); do
            log --diag "# $i/$COMPOSE_FILE"
            run_single "$i/$COMPOSE_FILE" || err=1
        done
        shift;
    done
    local clean_mode="-af"
    [ "$no_adv_clean" ] && clean_mode="-f"
    [ "$no_clean" ] || { log -I "Cleaning up..."; _docker system prune "$clean_mode"; } \
        || log -W "Error(s) occurred while cleaning up Docker storage."
    return "$err";
}

# Main #
IFS=$'\n'
[ "$MAINTENANCE_LOG" ] \
    || MAINTENANCE_LOG="./.last-maintenance.log"
rec=
scripts=()
scripts_pre=()
scripts_post=()
no_pull=
no_build=
no_sideload=
no_up=
no_clean=1
no_adv_clean=
dryrun=
while [ "$#" -gt 0 -a "${1:0:1}" = "-" ]; do
    case "$1" in
        "--recurse")
            rec="all"
            ;;
        "--recurse-one")
            rec=1
            ;;
        "--dry")
            dryrun=1
            ;;
        "--run")
            args_array "${@:2}"
            for i in ${REPLY}; do
                log --diag "--script $i"
                scripts+=("$i")
            done
            shift $COUNT
            ;;
        "--run-pre")
            args_array "${@:2}"
            for i in ${REPLY}; do
                log --diag "--on-pre $i"
                scripts_pre+=("$i")
            done
            shift $COUNT
            ;;
        "--run-post")
            args_array "${@:2}"
            for i in ${REPLY}; do
                log --diag "--on-post $i"
                scripts_post+=("$i")
            done
            shift $COUNT
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
            exit 0
            ;;
        *)
            log -E "Illegal option \`$1\`. Try --help for more information."
            exit 1;
            ;;
    esac
    shift
done
[ "$#" -gt 0 ] || {
    log -E 'No paths specified. Try --help for more information.'
}
[ "$dryrun" ] && log -W 'Dry-run mode. No actual maintenance operations are being performed.'
run "$@"