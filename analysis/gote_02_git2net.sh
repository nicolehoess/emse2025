#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/gote_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

# Analyse all subject projects with git2net.
for project in ${project_list[*]}
  do
    printf 'Analysing %s with git2net...\n' "$project"
    echo "Start:" `date -u`
    start=`date +%s`

    # Analyse the git log and create developer networks
    # based on adjacency matrix or edge list format.
    python3 "$src_path"/extract_git2net.py \
      --conf "$git2net_conf_path"/"gote_"$project".yml" \
      --network_mode "adjacency"

    python3 "$src_path"/extract_git2net.py \
      --conf "$git2net_conf_path"/"gote_"$project".yml" \
      --network_mode "edgelist"
  done

# Calculate productivity metrics with network metrics
# based on adjacency matrix or edge list format.
python3 "$src_path"/productivity.py \
        --tool git2net \
        --data_path "$git2net_data_path" \
        --save_path "$res_path"/git2net \
        --git_repo_path "$git_repo_path" \
        --projects "$project_str_list" \
        --conf_path "$git2net_conf_path" \
        --network_mode "adjacency"

python3 "$src_path"/productivity.py \
        --tool git2net \
        --data_path "$git2net_data_path" \
        --save_path "$res_path"/git2net \
        --git_repo_path "$git_repo_path" \
        --projects "$project_str_list" \
        --conf_path "$git2net_conf_path" \
        --network_mode "edgelist"
