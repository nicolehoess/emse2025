#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/gote_analysis.conf

Rscript "$plot_path"/plot_corr.R \
    --res_path "$res_path" \
    --repro_path "$reproducibility_data_path" \
    --network_mode "adjacency" \
    --tikz

Rscript "$plot_path"/plot_corr.R \
    --res_path "$res_path" \
    --repro_path "$reproducibility_data_path" \
    --network_mode "edgelist" \
    --tikz

bash "$plot_path"/gen_img.sh
