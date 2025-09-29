#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/gote_analysis.conf

# Analyse all subject projects with Codeface.
for project in ${project_list[*]}
  do
    echo "`codeface -j $cores run \
	  -c /home/emse/tools/codeface/snapshot/codeface.conf \
	  -p /home/emse/tools/codeface/snapshot/conf/gote_${project}.conf \
	  "$codeface_data_path" "$git_repo_path"`"
  done
  
eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

# Prepare Codeface's adjacency matrices for analysis.
for project in ${project_list[*]}
do
  echo "Preparing Codeface's developer networks for project $project..."
  python3 "$src_path"/network_codeface.py \
    --port "$port" \
    --data_path "$codeface_data_path"/"$project"/"proximity" \
    --save_path "$codeface_data_path"/networks/"$project"
done

python3 "$src_path"/productivity.py \
        --tool codeface \
        --data_path "$port" \
        --save_path "$res_path"/codeface \
        --git_repo_path "$git_repo_path" \
        --projects "$project_str_list" \
        --network_path "$codeface_data_path"/networks
