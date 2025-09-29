#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/joblin_analysis.conf

Rscript "$plot_path"/plot_metrics.R \
    --conf_path "$git2net_conf_path" \
    --res_path "$res_path" \
    --tikz

Rscript "$plot_path"/original_plot_metrics.R \
    --conf_path "$git2net_conf_path" \
    --res_path "$res_path" \
    --tikz

Rscript "$plot_path"/plot_tools.R \
    --conf_path "$git2net_conf_path" \
    --res_path "$res_path" \
    --tikz

bash "$plot_path"/gen_img.sh
