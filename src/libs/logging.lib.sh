#@func Emit a log message.
#@args [<<opts>>] [--|--msg|--message] [<<message-parts>>]
#@args [<<opts>>] --execute <command> [<<args>>]
#      -d: Emit only if $DEBUG is set.
#      -D|--diag:  Use the DIAG level (implies -d).
#      -I|--info:  Use the INFO level.
#      -W|--warn:  Use the WARN level.
#      -E|--fail:  Use the FAIL level.
#      --execute:  Intepret the positional arguments as a command to be logged and run.
#      --tag <s>:  Specify a string to be used as a source.
# @env $DEBUG: (Boolean) Needs to be set in order to emit messages flagged with -d or -D.
log() {
  #echo "$*" >&2
  local ts="$(date +'%Y-%m-%d %H:%M:%S %Z')"
  local msg_g=
  local tag="$LOG_TAG"
  local exec=
  local debug=
  while [ "${1:0:1}" = "-" ]; do
    case "$1" in
      "-d"|"--debug")
        debug=1;
        ;;
      "-D"|"--diag")
        msg_g="D:"
        ;;
      "-I"|"--info")
        msg_g="I:"
        ;;
      "-W"|"--warn")
        msg_g="W:"
        ;;
      "-E"|"--error"|"--fail")
        msg_g="E:"
        ;;
      "--execute")
        exec=1
        ;;
      "--tag")
        tag="$2"
        shift
        ;;
      "--"|"--msg"|"--message")
        shift
        break
        ;;
      *)
        break;
        ;;
    esac
    shift
  done
  local IFS=$' \n'
  {
    local msg_raw="$*"
    local msg="$msg_raw"
    [ "$msg_g" ] || { msg_g="${msg_raw:0:2}"; msg="${msg_raw:2}"; }
    [ "${msg:0:1}" = " " ] && msg="${msg:1}"
    case "$msg_g" in
      "W:"|"w:")
        printf '\033[1;37m[ \033[1;33mWARN \033[1;37m] \033[0;33m%s' "$ts"
        [ "$tag" ] && printf '\033[0;97m @\033[0;93m%s' "$tag";
        ;;
      "E:"|"e:")
        printf '\033[1;37m[ \033[1;31mFAIL \033[1;37m] \033[0;31m%s' "$ts"
        [ "$tag" ] && printf '\033[0;97m @\033[0;91m%s' "$tag";
        ;;
      "D:"|"d:")
        debug=1;
        if [ "$DEBUG" ]; then
          printf '\033[1;37m[ \033[1;35mDIAG \033[1;37m] \033[0;35m%s' "$ts"
          [ "$tag" ] && printf '\033[0;97m @\033[0;95m%s' "$tag";
        fi
        ;;
      *)
        [ "$msg_g" = "I:" -o "$msg_g" = "i:" ] || msg="$msg_raw"
        printf '\033[1;37m[ \033[1;32mINFO \033[1;37m] \033[0;32m%s' "$ts"
        [ "$tag" ] && printf '\033[0;97m @\033[0;92m%s' "$tag";
        ;;
    esac
    # Print message
    [ -z "$debug" -o "$DEBUG" ] && printf '\033[0;97m: %s\033[0m\n' "$msg"
  } >&2
  if [ "$exec" ]; then
    # Execute
    "$@"
    local ec="$?"
    log --diag " -> $ec"
    return "$ec"
  else
    return 0
  fi
}
