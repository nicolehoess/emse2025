#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/.bashrc
eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"

conda create --name emse python=3.10 pip -y
eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"

conda activate emse
pip install -r /home/emse/src/requirements.txt
sudo Rscript /home/emse/plot/packages.R
