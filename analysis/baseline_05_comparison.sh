#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/baseline_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

#python3 "$src_path"/baseline_codeface_merge.py

#Rscript "$plot_path"/plot_baseline.R \
#    --res_path "$res_path" \
#    --tikz

#Rscript "$plot_path"/plot_networks.R \
#    --res_path "$data_network_path" \
#    --projects "$plot_str_list" \
#    --tikz

bash "$plot_path"/gen_img.sh
