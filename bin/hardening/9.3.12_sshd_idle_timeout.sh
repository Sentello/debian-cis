#!/bin/bash

#
# CIS Debian 7 Hardening
# Authors : Thibault Dewailly, OVH <thibault.dewailly@corp.ovh.com>
#

#
# 9.3.12 Set Idle Timeout Interval for User Login (Scored)
#

set -e # One error, it's over
set -u # One variable unset, it's over

PACKAGE='openssh-server'
FILE='/etc/ssh/sshd_config'

# This function will be called if the script status is on enabled / audit mode
audit () {
    OPTIONS="ClientAliveInterval=$SSHD_TIMEOUT ClientAliveCountMax=0"
    is_pkg_installed $PACKAGE
    if [ $FNRET != 0 ]; then
        crit "$PACKAGE is not installed !"
    else
        ok "$PACKAGE is installed"
        for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo $SSH_OPTION | cut -d= -f 1)
            SSH_VALUE=$(echo $SSH_OPTION | cut -d= -f 2)
            PATTERN="^$SSH_PARAM[[:space:]]*$SSH_VALUE"
            does_pattern_exists_in_file $FILE "$PATTERN"
            if [ $FNRET = 0 ]; then
                ok "$PATTERN is present in $FILE"
            else
                crit "$PATTERN is not present in $FILE"
            fi
        done
    fi
}

# This function will be called if the script status is on enabled mode
apply () {
    is_pkg_installed $PACKAGE
    if [ $FNRET = 0 ]; then
        ok "$PACKAGE is installed"
    else
        crit "$PACKAGE is absent, installing it"
        apt_install $PACKAGE
    fi
    for SSH_OPTION in $OPTIONS; do
            SSH_PARAM=$(echo $SSH_OPTION | cut -d= -f 1)
            SSH_VALUE=$(echo $SSH_OPTION | cut -d= -f 2)
            PATTERN="^$SSH_PARAM[[:space:]]*$SSH_VALUE"
            does_pattern_exists_in_file $FILE "$PATTERN"
            if [ $FNRET = 0 ]; then
                ok "$PATTERN is present in $FILE"
            else
                warn "$PATTERN not present in $FILE, adding it"
                does_pattern_exists_in_file $FILE "^$SSH_PARAM"
                if [ $FNRET != 0 ]; then
                    add_end_of_file $FILE "$SSH_PARAM $SSH_VALUE"
                else
                    info "Parameter $SSH_PARAM is present but with the wrong value, correcting"
                    replace_in_file $FILE "^$SSH_PARAM[[:space:]]*.*" "$SSH_PARAM $SSH_VALUE"
                fi
                /etc/init.d/ssh reload
            fi
    done
}

# This function will check config parameters required
check_config() {
    if [ -z $SSHD_TIMEOUT ]; then
        crit "SSHD_TIMEOUT is not set, please edit configuration file"
        exit 128
    fi
}

# Source Root Dir Parameter
if [ ! -r /etc/default/cis-hardenning ]; then
    echo "There is no /etc/default/cis-hardenning file, cannot source CIS_ROOT_DIR variable, aborting"
    exit 128
else
    . /etc/default/cis-hardenning
    if [ -z $CIS_ROOT_DIR ]; then
        echo "No CIS_ROOT_DIR variable, aborting"
    fi
fi 

# Main function, will call the proper functions given the configuration (audit, enabled, disabled)
[ -r $CIS_ROOT_DIR/lib/main.sh ] && . $CIS_ROOT_DIR/lib/main.sh
