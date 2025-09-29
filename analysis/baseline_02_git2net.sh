#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/baseline_analysis.conf

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
      --conf "$git2net_conf_path"/"baseline_"$project".yml" \
      --network_mode "adjacency"
  done

python3 "$src_path"/network_annotate.py \
        --tool git2net \
        --data_path "$data_path/gote_2022/git2net" \
        --projects "$adjacency_str_list"

python3 "$src_path"/baseline_comparison.py \
        --tool git2net \
        --data_path "$data_path" \
        --save_path "$res_path"/git2net \
        --projects "$project_str_list" \
        --studies "$study_str_list" \
        --conf_path "$git2net_conf_path"
