# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Combines statistics from Codeface from multiple Docker containers.

import pandas as pd

df_1 = pd.read_csv("/home/emse/results/baseline/codeface/statistics_joblin.csv")
df_2 = pd.read_csv("/home/emse/results/baseline/codeface/statistics_gote.csv")

df = pd.concat([df_1, df_2], ignore_index=False)
df.to_csv("/home/emse/results/baseline/codeface/statistics.csv", index=False)
