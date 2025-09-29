#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Replicate Joblin et al., 2017.
bash /home/emse/analysis/joblin_00_git_repos.sh
bash /home/emse/analysis/joblin_02_git2net.sh
bash /home/emse/analysis/joblin_04_kaiaulu.sh

# Replicate Gote et al., 2022.
bash /home/emse/analysis/gote_00_git_repos.sh
bash /home/emse/analysis/gote_02_git2net.sh
bash /home/emse/analysis/gote_04_kaiaulu.sh

# Replicate Foucault et al., 2015.
bash /home/emse/analysis/foucault_00_git_repos.sh
bash /home/emse/analysis/foucault_02_git2net.sh
bash /home/emse/analysis/foucault_04_kaiaulu.sh

# Compute baseline data statistics.
bash /home/emse/analysis/baseline_02_git2net.sh
bash /home/emse/analysis/baseline_04_kaiaulu.sh
