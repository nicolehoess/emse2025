#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/joblin_analysis.conf

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
      --conf "$git2net_conf_path"/joblin_"$project".yml \
      --network_mode "adjacency"
  done

# Classify developers based on the git2net data set.
for project in ${project_list[*]}
do
  echo "Classifying developers in project $project..."
  python3 "$src_path"/core_developer.py \
    --tool "git2net" \
    --project "$project" \
    --data_path "$git2net_data_path"/"$project"/"$project"_line.db \
    --network_path "$git2net_data_path"/"$project"/line/coediting \
    --save_path "$res_path"/git2net/"$project" \
    --conf_path "$git2net_conf_path"/joblin_"$project".yml
done
