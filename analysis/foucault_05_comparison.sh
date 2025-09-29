#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

Rscript "$plot_path"/plot_activity.R \
    --res_path "$res_path" \
    --repro_path "$reproducibility_data_path"

Rscript "$plot_path"/plot_turnover_quality.R \
    --res_path "$res_path" \
    --repro_path "$reproducibility_data_path"

Rscript "$plot_path"/plot_tools.R \
    --res_path "$plot_path" \
    --repro_path "$reproducibility_data_path" \
    --tikz

bash "$plot_path"/gen_img.sh
