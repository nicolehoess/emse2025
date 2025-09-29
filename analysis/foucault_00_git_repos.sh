#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

# Clone the git repositories of all subject projects for
# the activity analysis (to mimic multi-branch analysis).
mkdir -p "$git_repo_path"
cd "$git_repo_path"

for project in ${project_list[*]}
  do
    if [ -d "$git_repo_path"/"$project" ]; then
      echo "$project already cloned"
    elif [ "$project" == "angular_js" ]; then
      git clone https://github.com/angular/angular.js.git
      mv angular.js angular_js
      cd angular_js
      git checkout d8f77817eb5c98dec5317bc3756d1ea1812bcfbe
      git checkout -b snapshot
    elif [ "$project" == "ansible" ]; then
      git clone https://github.com/ansible/ansible.git
      cd ansible
      git checkout faf86ca2b3e7b06660528d69a9839bb8d1409f70
      git checkout -b snapshot
    elif [ "$project" == "jenkins" ]; then
      git clone https://github.com/jenkinsci/jenkins.git
      cd jenkins
      git checkout 216273c8f269daf256fa0957199aa73989eaf8fa
      git checkout -b snapshot
    elif [ "$project" == "jquery" ]; then
      git clone https://github.com/matthieu-foucault/jquery.git
      cd jquery
      git checkout a35996141e3c1de92e89ed77eac1799124e747d3
      git checkout -b snapshot
    elif [ "$project" == "rails" ]; then
      git clone https://github.com/rails/rails.git
      cd rails
      git checkout 81d64b15bf63f9ad7b4cf68f362de882b622ba92
      git checkout -b snapshot
    fi
  done

# Clone the git repositories of all subject projects for
# the CLOC analysis (commit from original configs).
mkdir -p "$cloc_git_repo_path"
cd "$cloc_git_repo_path"

for project in ${project_list[*]}
  do
    if [ -d "$cloc_git_repo_path"/"$project" ]; then
      echo "$project for cloc already cloned"
    elif [ "$project" == "angular_js" ]; then
      git clone https://github.com/angular/angular.js.git
      mv angular.js angular_js
      cd angular_js
      git checkout 519bef4f3d1cdac497c782f77457fd2f67184601
    elif [ "$project" == "ansible" ]; then
      git clone https://github.com/ansible/ansible.git
      cd ansible
      git checkout 6221a2740f5c3023c817d13e4a564f301ed3bc73
    elif [ "$project" == "jenkins" ]; then
      git clone https://github.com/jenkinsci/jenkins.git
      cd jenkins
      git checkout 3991cd04fd13aa086c25820bdfaa9460f0810284
    elif [ "$project" == "jquery" ]; then
      git clone https://github.com/matthieu-foucault/jquery.git
      cd jquery
      git checkout 95559f5117c8a21c1b8cc99f4badc320fd3dcbda
    elif [ "$project" == "rails" ]; then
      git clone https://github.com/rails/rails.git
      cd rails
      git checkout 73fc42cc0b5e94541480032c2941a50edd4080c2
    fi
  done

# Clone the git repositories of all subject projects for
# bug analysis (to mimic multi-branch analysis).
mkdir -p "$bug_git_repo_path"
cd "$bug_git_repo_path"

for project in ${project_list[*]}
  do
    if [ -d "$bug_git_repo_path"/"$project" ]; then
      echo "$project for bug analysis already cloned"
    elif [ "$project" == "angular_js" ]; then
      git clone https://github.com/angular/angular.js.git
      mv angular.js angular_js_bug
      cd angular_js_bug
      git checkout v1.0.x
    elif [ "$project" == "ansible" ]; then
      git clone https://github.com/ansible/ansible.git
      mv ansible ansible_bug
      cd ansible_bug
      git checkout release1.5.5
    elif [ "$project" == "jenkins" ]; then
      git clone https://github.com/jenkinsci/jenkins.git
      mv jenkins jenkins_bug
      cd jenkins_bug
      git checkout stable-1.509
    elif [ "$project" == "jquery" ]; then
      git clone https://github.com/matthieu-foucault/jquery.git
      mv jquery jquery_bug
      cd jquery_bug
      git checkout 1.8-stable
    elif [ "$project" == "rails" ]; then
      git clone https://github.com/rails/rails.git
      mv rails rails_bug
      cd rails_bug
      git checkout 2-3-stable
    fi
  done
