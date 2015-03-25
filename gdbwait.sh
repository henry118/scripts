#!/bin/sh
#
# Usage: gdbwait.sh program

progstr=$1
progpid=$(pgrep -o "$progstr")
while [ -z "$progpid" ]; do
    progpid=$(pgrep -o "$progstr")
done
gdb -p "$progid"
