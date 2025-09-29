# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Creates a data set for plotting from the manually labeled literature lists.

import os
import pandas as pd
import time


venue_dir = "/home/emse/literature/venues"

df_plot = pd.read_csv(os.path.join(venue_dir, "summary_template.csv"), sep=";")
df_plot = df_plot.fillna("")
df_venue_list = []

# Check that categories are correct.
primary = []
secondary = []
tertiary = []

for f in os.listdir(venue_dir):
    if f == "summary_template.csv" or f == "venue_overview.csv" or f == "plot_summary.csv":
        continue

    if f.endswith(".csv"):
        print("Processing "+f+"...")
        df = pd.read_csv(os.path.join(venue_dir, f), sep=";")

        # Some post-processing to correct grouping and manual labeling.
        df = df.fillna("")
        df = df.replace("re-design", "redesign", regex=True)
        df = df.replace("re-engineering", "reengineering", regex=True)
        df = df.replace("data set", "dataset", regex=True)
        df = df.replace("productivty", "productivity", regex=True)
        df = df.replace("activity", "activity and productivity")
        df = df.replace("productivity", "activity and productivity")
        df = df.replace("MSR threats", "threats", regex=True)
        df = df.replace("bad practices", "patterns", regex=True)
        df = df.replace("classification", "patterns", regex=True)
        df = df.replace("merge conflicts", "code merge", regex=True)
        df = df.replace("experience", "expertise", regex=True)

        # Remove tertiary categories for which we found only one or zero studies.
        cond = df["Secondary Category 1"].str.lower() == "activity and productivity"
        df.loc[cond, "Tertiary Category 1"] = ""
        cond = df["Secondary Category 2"].str.lower() == "activity and productivity"
        df.loc[cond, "Tertiary Category 2"] = ""
        cond = df["Secondary Category 3"].str.lower() == "activity and productivity"
        df.loc[cond, "Tertiary Category 3"] = ""

        cond = df["Secondary Category 1"].str.lower() == "summarisation"
        df.loc[cond, "Tertiary Category 1"] = ""
        cond = df["Secondary Category 2"].str.lower() == "summarisation"
        df.loc[cond, "Tertiary Category 2"] = ""
        cond = df["Secondary Category 3"].str.lower() == "summarisation"
        df.loc[cond, "Tertiary Category 3"] = ""

        cond = df["Secondary Category 1"].str.lower() == "parallelisation"
        df.loc[cond, "Secondary Category 1"] = ""
        cond = df["Secondary Category 2"].str.lower() == "parallelisation"
        df.loc[cond, "Secondary Category 2"] = ""
        cond = df["Secondary Category 3"].str.lower() == "parallelisation"
        df.loc[cond, "Secondary Category 3"] = ""

        cond = (df["Tertiary Category 1"].str.lower() == "project success") & (df["Secondary Category 1"].str.lower() == "software governance")
        df.loc[cond, "Tertiary Category 1"] = ""
        cond = (df["Tertiary Category 2"].str.lower() == "project success") & (df["Secondary Category 2"].str.lower() == "software governance")
        df.loc[cond, "Tertiary Category 2"] = ""
        cond = (df["Tertiary Category 3"].str.lower() == "project success") & (df["Secondary Category 3"].str.lower() == "software governance")
        df.loc[cond, "Tertiary Category 3"] = ""

        cond = (df["Tertiary Category 1"].str.lower() == "code review generation") & (df["Secondary Category 1"].str.lower() == "generation")
        df.loc[cond, "Tertiary Category 1"] = ""
        cond = (df["Tertiary Category 2"].str.lower() == "code review generation") & (df["Secondary Category 2"].str.lower() == "generation")
        df.loc[cond, "Tertiary Category 2"] = ""
        cond = (df["Tertiary Category 3"].str.lower() == "code review generation") & (df["Secondary Category 3"].str.lower() == "generation")
        df.loc[cond, "Tertiary Category 3"] = ""

        cond = ((df["Tertiary Category 1"].str.lower() == "detection") | (df["Tertiary Category 1"].str.lower() == "prediction") | (df["Tertiary Category 1"].str.lower() == "localisation")) & (df["Secondary Category 1"].str.lower() == "vulnerabilities and security")
        df.loc[cond, "Tertiary Category 1"] = "detection, prediction and localisation"
        cond = ((df["Tertiary Category 2"].str.lower() == "detection") | (df["Tertiary Category 2"].str.lower() == "prediction") | (df["Tertiary Category 2"].str.lower() == "localisation")) & (df["Secondary Category 2"].str.lower() == "vulnerabilities and security")
        df.loc[cond, "Tertiary Category 2"] = "detection, prediction and localisation"
        cond = ((df["Tertiary Category 3"].str.lower() == "detection") | (df["Tertiary Category 3"].str.lower() == "prediction") | (df["Tertiary Category 3"].str.lower() == "localisation")) & (df["Secondary Category 3"].str.lower() == "vulnerabilities and security")
        df.loc[cond, "Tertiary Category 3"] = "detection, prediction and localisation"

        #print("primary: "+str(sorted(pd.unique(df[["Primary Category 1", "Primary Category 2", "Primary Category 3"]].values.ravel()))))
        #print("secondary: "+str(sorted(pd.unique(df[["Secondary Category 1", "Secondary Category 2", "Secondary Category 3"]].values.ravel()))))
        #print("tertiary: "+str(sorted(pd.unique(df[["Tertiary Category 1", "Tertiary Category 2", "Tertiary Category 3"]].values.ravel()))))

        primary += list(pd.unique(df[["Primary Category 1", "Primary Category 2", "Primary Category 3"]].values.ravel()))
        secondary += list(pd.unique(df[["Secondary Category 1", "Secondary Category 2", "Secondary Category 3"]].values.ravel()))
        tertiary += list(pd.unique(df[["Tertiary Category 1", "Tertiary Category 2", "Tertiary Category 3"]].values.ravel()))

        for idx, row in df.iterrows():
            cond = (df_plot["Primary"].str.lower() == row["Primary Category 1"].lower()) & (
                        df_plot["Secondary"].str.lower() == row["Secondary Category 1"].lower()) & (
                            df_plot["Tertiary"].str.lower() == row["Tertiary Category 1"].lower())
            df_plot.loc[cond, "Count"] += 1

            cond = (df_plot["Primary"].str.lower() == row["Primary Category 2"].lower()) & (
                        df_plot["Secondary"].str.lower() == row["Secondary Category 2"].lower()) & (
                            df_plot["Tertiary"].str.lower() == row["Tertiary Category 2"].lower())
            df_plot.loc[cond, "Count"] += 1

            cond = (df_plot["Primary"].str.lower() == row["Primary Category 3"].lower()) & (
                        df_plot["Secondary"].str.lower() == row["Secondary Category 3"].lower()) & (
                               df_plot["Tertiary"].str.lower() == row["Tertiary Category 3"].lower())
            df_plot.loc[cond, "Count"] += 1

        msr = len(df.loc[df["Primary Category 1"].str.lower() != "no msr study"])
        no_msr = len(df.loc[df["Primary Category 1"].str.lower() == "no msr study"])
        entry = pd.DataFrame.from_dict({
            "venue": [f.split(".")[0]],
            "msr": [msr],
            "no_msr": [no_msr],
            "total": [len(df)]
        })
        df_venue_list.append(entry)

print("\nPrimary categories:")
for e in sorted(set(primary)):
    print(e)
print("\nSecondary categories:")
for e in sorted(set(secondary)):
    print(e)
print("\nTertiary categories:")
for e in sorted(set(tertiary)):
    print(e)

print("\nSuccessfully mapped "+str(sum(df_plot["Count"]))+" topics.")

# Save summary data.
df_plot.to_csv(os.path.join(venue_dir, "plot_summary.csv"), index=False)
df_venue_overview = pd.concat(df_venue_list, ignore_index=False)
total_row = df_venue_overview.sum(numeric_only=True).astype(int)
total_df = pd.DataFrame([total_row], index=["Total"])
df_venue_overview = pd.concat([df_venue_overview, total_df])
df_venue_overview.to_csv(os.path.join(venue_dir, "venue_overview.csv"), index=False)
