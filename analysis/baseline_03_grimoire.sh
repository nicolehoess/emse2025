#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/baseline_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

python3 "$src_path"/baseline_comparison.py \
        --tool grimoire \
        --data_path 9200 \
        --save_path "$res_path"/grimoire \
        --projects "$project_str_list" \
        --studies "$study_str_list" \
        --conf_path "$grimoire_conf_path"

python3 "$src_path"/network_annotate.py \
        --tool grimoire \
        --data_path 9200 \
        --projects "$adjacency_str_list" \
        --network_path "$data_path/gote_2022/grimoire"
