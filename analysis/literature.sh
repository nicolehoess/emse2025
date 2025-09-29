#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/literature_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda activate emse

python3 "$src_path"/literature.py

Rscript "$plot_path"/plot_literature.R \
    --res_path "$literature_path/plot_summary.csv" \
    --tikz

bash "$plot_path"/gen_img.sh
