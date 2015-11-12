#!/bin/sh

#
# keywords
#
gmail_pass=""
outlook_pass=""
work_pass=""
procmail_bin=""
sed_bin="sed -r"

#
# cross platform sed
#
function guess_sed {
    local platform=$(uname)
    case $platform in
        Linux)
        ;;
        Darwin|FreeBSD)
            sed_bin="sed -E"
            ;;
    esac
}

#
# this function load the keys from keys.txt file if needed
#
function load_keys {
    if [ -f ./keys.txt ]; then
        source ./keys.txt
    fi
}

#
# get the procmail path
#
function procmail_path {
    if [ -z "$procmail_bin"] ; then
        procmail_bin=$(type -p procmail)
        if [ -z "$procmail_bin" ]; then
            echo "ERROR: can't find procmail binary, probably not installed?"
            exit 1
        fi
    fi
}

#
# This function does the actual patch
#
function do_patch {
    local src=$1
    local dst=$2
    local mode=$3
    if [ ! -f $dst -o ! -s $dst ]; then
        load_keys
        $sed_bin \
            -e "s|<gmail_pass>|$gmail_pass|g" \
            -e "s|<outlook_pass>|$outlook_pass|g" \
            -e "s|<work_pass>|$work_pass|g" \
            -e "s|<procmail>|$procmail_bin|g" \
            -e "s|<USER>|$USER|g" \
            < $src \
            > $dst
        if [ ! -z "$mode" ]; then
            chmod $mode $dst
        fi
    fi
}

#
# Patch the rc files
#
# I am using '|' instead of '/' for sed because $procmail_bin
# contains '/' which invalidates sed command
#
function patch_rcfiles {
    do_patch dotforward ~/.forward
    do_patch dotfetchmailrc ~/.fetchmailrc 600
    if type -p esmtp > /dev/null; then
        do_patch dotesmtprc ~/.esmtprc 600
    fi
    if type -p msmtp > /dev/null; then
        do_patch dotmsmtprc ~/.msmtprc 600
    fi
}

#
# Delete exsiting rc files
#
function delete_rcfiles {
    rm -f ~/.forward ~/.fetchmailrc ~/.esmtprc ~/.msmtprc
}

#
# crontab for 'fetchmail'
#
function setup_cron {
    crontab -l > ~/.mycron
    if ! grep -q 'fetchmail' ~/.mycron; then
        local fetchmail_bin=$(type -p fetchmail)
        if [ -z $fetchmail_bin ]; then
            echo "ERROR: fetchmail not found. possibly not installed?"
            exit 1
        fi
        echo "* * * * * $fetchmail_bin >/dev/null 2>&1" >> ~/.mycron
        crontab ~/.mycron
    fi
    rm ~/.mycron
}

#
# main
#
while getopts :d opt; do
    case $opt in
        d)
            delete_rcfiles
            ;;
        *)
            echo "usage: `basename $0` [-d]"
            exit 2
    esac
done
shift `expr $OPTIND - 1`
OPTIND=1

load_keys
procmail_path
guess_sed
patch_rcfiles
# no need to cron, instead, use 'fetchmail -d 60'
#setup_cron
