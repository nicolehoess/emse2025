#!/bin/bash
# Copyright Roger Meier <roger@bufferoverflow.ch>
# SPDX-License-Identifier:	Apache-2.0 BSD-2-Clause GPL-2.0+ MIT WTFPL

echo "Providing codeface python"

sudo pip2 install --upgrade setuptools
sudo pip2 install --upgrade mock
sudo pip2 install --upgrade subprocess32
sudo pip2 install --upgrade jira
sudo pip2 install --upgrade progressbar
sudo pip2 install --upgrade VCS
sudo pip2 install --upgrade python-ctags3
sudo pip2 install --upgrade "pyyaml<6"
sudo pip2 install --upgrade mysqlclient
sudo pip2 install --upgrade "wcwidth<0.2"
sudo pip2 install --upgrade "ftfy<5"
sudo pip2 install --upgrade lxml==5.0.2
sudo pip2 install --upgrade dicttoxml
sudo pip2 install backports.functools_lru_cache

# Only development mode works
# install fails due to R scripts accessing unbundled resources!
# TODO Fix the R scripts
sudo python2.7 setup.py develop
