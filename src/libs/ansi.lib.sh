#!/bin/bash
#@func Remove ANSI sequences from the input stream.
ansi-strip() {
    sed 's/\x1b\[[0-9;]*m//g' "$@"
}

export -f ansi-strip