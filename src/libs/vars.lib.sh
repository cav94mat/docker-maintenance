#!/bin/bash

#@const Value for true
readonly export true=1
#@const Value for false
readonly export false=0

#@func Evaluate a boolean value.
# @syntax <value> [<default>]
# @arg  <value>:    Value to interpolate as boolean.
# @arg  <default>:  Value to assume if <value> is empty (default '0')
# @exit 0:  The value evaluates to true,
#       1:  otherwise.
is-true() {    
    case "${1:-${2:-0}}" in
        '0'|'false'|'')
            return 1
            ;;
        *)
            return 0
            ;;
    esac
}
export -f is-true

#@func Evaluate a boolean value.
# @syntax <value> [<default>]
# @arg  <value>:    Value to interpolate as boolean.
# @arg  <default>:  Value to assume if <value> is empty (default '0')
# @exit 0:  The value evaluates to false,
#       1:  otherwise.
is-false() {
    ! is-true "$@"
}
export -f is-false

#@func Determine whether $DEBUG is specified and enabled.
# @exit 0:  Debugging is enabled in the environment,
#       1:  otherwise.
is-debug() {
    is-true "$DEBUG"
}
export -f is-debug