#!/bin/sh

if [ "$#" -ne 1 ]; then
    echo "Usage: $(basename $0) output"
    exit 1
fi

INFO=$(xwininfo -frame)
WIN_GEO=$(echo $INFO | grep -oE 'geometry [0-9]+x[0-9]+' | grep -oE '[0-9]+x[0-9]+')
WIN_XY=$(echo $INFO | grep -oE 'Corners:\s+\+[0-9]+\+[0-9]+' | grep -oE '[0-9]+\+[0-9]+' | sed -r 's/\+/,/')
ffmpeg -f x11grab -r 15 -s $WIN_GEO -i $DISPLAY+$WIN_XY $1
