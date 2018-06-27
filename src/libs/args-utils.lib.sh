REPLY=
COUNT=
args_array() {
    REPLY=
    COUNT=1
    if [ "$#" = 0 ]; then
        COUNT=0
        REPLY=$'\n'
    elif [ "$1" = "[" ]; then
        COUNT=2
        shift
        while [ "$1" != "]" ]; do
            COUNT=$((${COUNT}+1))
            REPLY="${REPLY}${1}"$'\n'
            shift
        done
    else
        REPLY="$1"$'\n'
    fi
    shift
}