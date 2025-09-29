#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

# Analyse all subject projects with Codeface.
for project in ${project_list[*]}
  do
    echo "`codeface -j $cores run \
	  -c /home/emse/tools/codeface/snapshot/codeface.conf \
	  -p /home/emse/tools/codeface/snapshot/conf/foucault_${project}.conf \
	  "$codeface_data_path" "$git_repo_path"`"

    echo "`codeface -j $cores run \
	  -c /home/emse/tools/codeface/snapshot/codeface.conf \
	  -p /home/emse/tools/codeface/snapshot/conf/foucault_${project}_bug.conf \
	  "$codeface_data_path" "$bug_git_repo_path"`"
  done

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

python3 "$src_path"/turnover.py \
        --tool codeface \
        --data_path "$port" \
        --git_repo_path "$cloc_git_repo_path" \
        --bug_fix_path "$bug_fix_path" \
        --save_path "$res_path"/codeface \
        --projects "$project_str_list"
