#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

python3 "$src_path"/turnover.py \
        --tool grimoire \
        --data_path 9200 \
        --git_repo_path "$cloc_git_repo_path" \
        --bug_fix_path "$bug_fix_path" \
        --save_path "$res_path"/grimoire \
        --projects "$project_str_list"
