#!/bin/sh

if [ ! -f ./keys.txt ]; then
    echo "ERROR: file \"keys.txt\" doesn't exist."
    exit 1
fi

source ./keys.txt

if [ -z "$gmail_pass" -o -z "$outlook_pass" ]; then
    echo "ERROR: \$gmail_pass or \$outlook_pass is empty."
    exit 1
fi

procmail_bin=$(which procmail)
if [ -z "$procmail_bin" ]; then
    echo "ERROR: can't find procmail binary, probably not installed?"
    exit 1
fi

# I am using '|' instead of '/' for sed because $procmail_bin
# contains '/' which invalidates sed command

#
# ~/.forward
#
sed -r \
    -e "s|<procmail>|$procmail_bin|g" \
    -e "s|<USER>|$USER|g" \
    < dotforward \
    > ~/.forward

#
# ~/.esmtp.rc
#
sed -r \
    -e "s|<gmail_pass>|$gmail_pass|g" \
    -e "s|<outlook_pass>|$outlook_pass|g" \
    -e "s|<procmail>|$procmail_bin|g" \
    < dotesmtprc \
    > ~/.esmtprc

chmod 600 ~/.esmtprc

#
# ~/.fetchmail.rc
#
sed -r \
    -e "s|<gmail_pass>|$gmail_pass|g" \
    -e "s|<outlook_pass>|$outlook_pass|g" \
    -e "s|<procmail>|$procmail_bin|g" \
    -e "s|<USER>|$USER|g" \
    < dotfetchmailrc \
    > ~/.fetchmailrc

chmod 600 ~/.fetchmailrc
