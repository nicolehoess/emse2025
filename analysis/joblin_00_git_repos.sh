#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/joblin_analysis.conf

# Clone the git repositories of all subject projects.
mkdir -p "$git_repo_path"
cd "$git_repo_path"

for project in ${project_list[*]}
  do
    if [ -d "$git_repo_path"/"$project" ]; then
      echo "$project already cloned"
    elif [ "$project" == "django" ]; then
      git clone https://github.com/django/django.git
      cd django
      git checkout 6f229048ddd8c7347ff60dddfb9121e6021c7b2e
      git checkout -b snapshot-2015-12-06
    elif [ "$project" == "ffmpeg" ]; then
      git clone https://git.ffmpeg.org/ffmpeg.git
      cd ffmpeg
      git checkout 9ac61e73d0843ec4b83f4e3d47eded73234e406e
      git checkout -b snapshot-2015-11-08
    elif [ "$project" == "gcc" ]; then
      git clone git://gcc.gnu.org/git/gcc.git
      cd gcc
      git checkout 4ee6515e8308b979e7413694073f2dd93c846750
      git checkout -b snapshot-2015-11-03
    elif [ "$project" == "llvm-project" ]; then
      git clone https://github.com/llvm/llvm-project.git
      cd llvm-project
      git checkout cf2ed26836bf186d6a3a52a84690662da2b451e9
      git checkout -b snapshot-2015-11-02
    elif [ "$project" == "postgresql" ]; then
      git clone https://git.postgresql.org/git/postgresql.git
      cd postgresql
      git checkout db0723631ef1460e9e795c6d13abb19da403a3f1
      git checkout -b snapshot-2015-12-05
    elif [ "$project" == "qemu" ]; then
      git clone https://gitlab.com/qemu-project/qemu.git
      cd qemu
      git checkout aa5ccadcca3e6018ebd9d2e8b0a0604f7cb0cd59
      git checkout -b snapshot-2015-11-02
    elif [ "$project" == "u-boot" ]; then
      git clone https://github.com/u-boot/u-boot.git
      cd u-boot
      git checkout a61047370d0b73ab886c5863e952695b5ee0d75b
      git checkout -b snapshot-2015-11-01
    elif [ "$project" == "wine" ]; then
      git clone https://gitlab.winehq.org/wine/wine.git
      cd wine
      git checkout a0d0d0dd0a5b4a500ab8d37cc6e687a202997d56
      git checkout -b snapshot-2015-11-06
    fi
  done