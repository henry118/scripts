#!/bin/sh
#
# This script disables the "alternate screen"
# feature found on most modern Linux distros
#

termsrc=/tmp/${TERM}.src
infocmp -l $TERM > $termsrc
sed -r -i -e 's/smcup=.*,//' -e 's/rmcup=.*,//' $termsrc
mkdir -p ~/.terminfo
tic $termsrc
rm $termsrc
