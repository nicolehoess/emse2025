#! /bin/sh
# Copyright 2016, Wolfgang Mauerer <wm@linux-kernel.net>
# -*- yaml -*-
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# The purpose of this script is to demonstrate an example analysis
# with Codeface.

# Vagrant-based installation
if [ -d /vagrant ]; then
    if [ ! -d $HOME/git-repos ]; then
        mkdir git-repos
    fi
    if [ ! -d $HOME/res ]; then
        mkdir res
    fi

    # Clone git repository
    (cd $HOME/git-repos; git clone https://gitlab.com/qemu-project/qemu/)

    # Run default analyses
    codeface -j4 run \
        -c /vagrant/codeface.conf \
        -p /vagrant/conf/qemu.conf \
        $HOME/res $HOME/git-repos

# Docker-based installation
elif [ -d $HOME/codeface/codeface ]; then
    # Clone git repository
    (cd $HOME/git-repos; git clone https://gitlab.com/qemu-project/qemu/)

    # Run default analyses
    codeface -j4 run \
        -c $HOME/codeface/codeface.conf \
        -p $HOME/codeface/conf/qemu.conf \
        $HOME/res $HOME/git-repos

else
    echo "This script assumes a docker or vagrant based setup."
    echo "Aborting..."
    echo "Please adjust this script to your custom paths."
fi
