#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/gote_analysis.conf

# Clone the git repositories of all subject projects.
mkdir -p "$git_repo_path"
cd "$git_repo_path"

for project in ${project_list[*]}
  do
    if [ -d "$git_repo_path"/"$project" ]; then
      echo "$project already cloned"
    elif [ "$project" == "ansible" ]; then
      git clone https://github.com/ansible/ansible.git
      cd ansible
      git checkout 6c2be04b6fe19b8cd3151ede89d6e10ef6acb031
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "birt" ]; then
      git clone https://github.com/eclipse-birt/birt.git
      cd birt
      git checkout dff3eaf55c18f294fadafc94c7bbcda83c65970c
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "conductor" ]; then
      git clone https://github.com/Netflix/conductor.git
      cd conductor
      git checkout 2f428988c1f4ce75babe706554db1dc4ab72a66b
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "cpython" ]; then
      git clone https://github.com/python/cpython.git
      cd cpython
      git checkout 896f4cf63f9ab93e30572d879a5719d5aa2499fb
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "flink" ]; then
      git clone https://github.com/apache/flink.git
      cd flink
      git checkout 4aa6524feda52b7382593f49df23d469489ca84b
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "gtk" ]; then
      git clone https://github.com/GNOME/gtk.git
      cd gtk
      git checkout 1d0235780cb79e80ec93249b807a81aba9806e84
      git checkout -b snapshot-2020-06-13
    elif [ "$project" == "homebrew" ]; then
      git clone https://github.com/Homebrew/homebrew-core.git
      cd homebrew-core
      git checkout fd2152a57a6a26b51e5a391f9efddadb4ea5b5d0
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "netxms" ]; then
      git clone https://github.com/netxms/netxms.git
      cd netxms
      git checkout 7f8f2ae397a9ad57863cfdaca66703d2d8d9c616
      git checkout -b snapshot-2020-06-11
    elif [ "$project" == "sofa" ]; then
      git clone https://github.com/sofa-framework/sofa.git
      cd sofa
      git checkout 3a19cd4aaeb6c06403d4a7f0773b9f5ea7b35a7c
      git checkout -b snapshot-2020-06-13
    elif [ "$project" == "vc" ]; then
      git clone https://github.com/VcDevel/Vc.git
      mv Vc vc
      cd vc
      git checkout 6808742be78502ea68866e0a8c860cf1408a91ed
      git checkout -b snapshot-2020-06-13
    fi
  done