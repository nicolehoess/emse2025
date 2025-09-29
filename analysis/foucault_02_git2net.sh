#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

# Analyse all subject projects with git2net.
for project in ${project_list[*]}
  do
    printf 'Analysing %s with git2net...\n' "$project"
    echo "Start:" `date -u`
    start=`date +%s`

    # Analyse the git log.
    python3 "$src_path"/extract_git2net.py \
      --conf "$git2net_conf_path"/"foucault_"$project".yml" \
      --network_mode "adjacency"

    python3 "$src_path"/extract_git2net.py \
      --conf "$git2net_conf_path"/"foucault_"$project"_bug.yml" \
      --network_mode "adjacency"
  done

python3 "$src_path"/turnover.py \
        --tool git2net \
        --data_path "$git2net_data_path" \
        --git_repo_path "$cloc_git_repo_path" \
        --bug_fix_path "$bug_fix_path" \
        --save_path "$res_path"/git2net \
        --projects "$project_str_list"
