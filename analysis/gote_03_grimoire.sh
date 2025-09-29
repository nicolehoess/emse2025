#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/gote_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

# Prepare GrimoireLab's adjacency matrices for analysis.
for project in ${project_list[*]}
do
  echo "Preparing GrimoireLab's developer networks for project $project..."
  python3 "$src_path"/network_grimoire.py \
    --conf_path "$grimoire_conf_path"/gote_"$project".yml \
    --network_path "$grimoire_data_path"/"$project"/networks
done

# Calculate productivity metrics.
python3 "$src_path"/productivity.py \
        --tool grimoire \
        --data_path 9200 \
        --save_path "$res_path"/grimoire \
        --git_repo_path "$git_repo_path" \
        --projects "$project_str_list" \
        --conf_path "$grimoire_conf_path" \
        --network_path "$grimoire_data_path"
