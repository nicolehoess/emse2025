#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Summarise literature review results.
bash /home/emse/analysis/literature.sh

# Prepare replications for GrimoireLab.
bash /home/emse/analysis/joblin_03_grimoire.sh
bash /home/emse/analysis/gote_03_grimoire.sh
bash /home/emse/analysis/foucault_03_grimoire.sh
bash /home/emse/analysis/baseline_03_grimoire.sh

# Compare baseline data and results for the three replication studies.
bash /home/emse/analysis/joblin_05_comparison.sh
bash /home/emse/analysis/gote_05_comparison.sh
bash /home/emse/analysis/foucault_05_comparison.sh
bash /home/emse/analysis/baseline_05_comparison.sh
