#!/bin/sh

#
# keywords
#
gmail_pass=""
outlook_pass=""
procmail_bin=""

#
# this function load the keys from keys.txt file if needed
#
function load_keys {
    if [ -z "$gmail_pass" -o -z "$outlook_pass" ]; then
        if [ ! -f ./keys.txt ]; then
            echo "ERROR: file \"keys.txt\" doesn't exist."
            exit 1
        fi
        source ./keys.txt
        if [ -z "$gmail_pass" -o -z "$outlook_pass" ]; then
            echo "ERROR: \$gmail_pass or \$outlook_pass is empty."
            exit 1
        fi
    fi
}

#
# get the procmail path
#
function procmail_path {
    if [ -z "$procmail_bin"] ; then
        procmail_bin=$(which procmail)
        if [ -z "$procmail_bin" ]; then
            echo "ERROR: can't find procmail binary, probably not installed?"
            exit 1
        fi
    fi
}


#
# Patch the rc files
#
# I am using '|' instead of '/' for sed because $procmail_bin
# contains '/' which invalidates sed command
#
function patch_rcs {

    # ~/.forward
    if [ ! -f ~/.forward ]; then
        load_keys
        sed -r \
            -e "s|<procmail>|$procmail_bin|g" \
            -e "s|<USER>|$USER|g" \
            < dotforward \
            > ~/.forward
    fi

    # ~/.esmtprc
    if [ ! -f ~/.esmtprc ]; then
        load_keys
        sed -r \
            -e "s|<gmail_pass>|$gmail_pass|g" \
            -e "s|<outlook_pass>|$outlook_pass|g" \
            -e "s|<procmail>|$procmail_bin|g" \
            < dotesmtprc \
            > ~/.esmtprc
        chmod 600 ~/.esmtprc
    fi

    # ~/.fetchmailrc
    if [ ! -f ~/.fetchmailrc ]; then
        load_keys
        sed -r \
            -e "s|<gmail_pass>|$gmail_pass|g" \
            -e "s|<outlook_pass>|$outlook_pass|g" \
            -e "s|<procmail>|$procmail_bin|g" \
            -e "s|<USER>|$USER|g" \
            < dotfetchmailrc \
            > ~/.fetchmailrc
        chmod 600 ~/.fetchmailrc
    fi
}

#
# crontab for 'fetchmail'
#
function setup_cron {
    crontab -l > ~/.mycron
    if ! grep -q 'fetchmail' ~/.mycron; then
        echo "* * * * * fetchmail >/dev/null 2>&1" >> ~/.mycron
        crontab ~/.mycron
    fi
    rm ~/.mycron
}

#
# main
#
procmail_path
patch_rcs
setup_cron
