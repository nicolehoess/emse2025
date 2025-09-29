#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/joblin_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

# Prepare GrimoireLab's adjacency matrices for analysis and classify developers.
for project in ${project_list[*]}
do
  echo "Preparing GrimoireLab's developer networks for project $project..."
  python3 "$src_path"/network_grimoire.py \
    --conf_path "$grimoire_conf_path"/joblin_"$project".yml \
    --network_path "$grimoire_data_path"/"$project"/networks

  echo "Classifying developers based on GrimoireLab's data set for project $project..."
  python3 "$src_path"/core_developer.py \
      --tool "grimoire" \
      --project "$project" \
      --data_path 9200 \
      --network_path "$grimoire_data_path"/"$project"/networks \
      --save_path "$res_path"/grimoire/"$project" \
      --conf_path "$grimoire_conf_path"/joblin_"$project".yml
done
