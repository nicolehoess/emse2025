#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/joblin_analysis.conf

# Analyse all subject projects with Codeface.
for project in ${project_list[*]}
  do
    echo "`codeface -j $cores run \
	  -c /home/emse/tools/codeface/snapshot/codeface.conf \
	  -p /home/emse/tools/codeface/snapshot/conf/joblin_${project}.conf \
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
    --save_path "$codeface_data_path"/"$project"/"proximity"/networks
done

# Classify developers based on the Codeface data set.
for project in ${project_list[*]}
do
  echo "Classifying developers in project $project..."
  python3 "$src_path"/core_developer.py \
    --tool "codeface" \
    --project "$project" \
    --data_path "$port" \
    --network_path "$codeface_data_path"/"$project"/"proximity"/networks \
    --save_path "$res_path"/codeface/"$project"
done
