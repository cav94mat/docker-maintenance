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
# Main
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