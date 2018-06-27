run_single() { # <stack>
    log --diag "run_single: $1"
    local dir="$(dirname "$1")"
    (
        export stat_pull=
        export stat_build=
        export stat_scripts=
        export stat_up=
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
        stat_pull=1
        [ "$no_pull" ] || { log -I "Pulling images..."; _docker_compose pull --parallel --ignore-pull-failures; } \
            || {
                log -W "Error(s) occurred while pulling updated images."
                stat_pull=0
            }
        # 2. Build
        stat_build=1
        [ "$no_build" ] || { log -I "Re-building local images..."; _docker_compose build --pull --no-cache; } \
            || {
                log -W "Error(s) occurred while re-building local images."
                stat_build=0
            } 
        # 3. Stop
        { log -I "Stopping active containers..."; _docker_compose build --pull --no-cache; } \
            || {
                log -E "Error(s) occurred while stopping active containers."
                return 1
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
        stat_up=1
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
        log --diag "run: $1 -maxdepth $maxdepth -name $COMPOSE_FILE"
        for i in $(find "$1" -maxdepth $maxdepth -name "$COMPOSE_FILE"); do
            run_single "$i" || err=1
        done
        shift;
    done
    local clean_mode="-af"
    [ "$no_adv_clean" ] && clean_mode="-f"
    [ "$no_clean" ] || { log -I "Cleaning up..."; _docker system prune "$clean_mode"; } \
        || log -W "Error(s) occurred while cleaning up Docker storage."
    return "$err";
}