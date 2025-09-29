#!/bin/bash

# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

source /home/emse/analysis/foucault_analysis.conf

eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"

# Analyse all subject projects with Kaiaulu.
for project in ${project_list[*]}
  do
   conda activate kaiaulu
   printf 'Analysing %s with Kaiaulu...\n' "$project"
   # Analyse the git log.
   mkdir -p "${kaiaulu_raw_data_path}"/gitlog/"${project}"/entities
   Rscript "${kaiaulu_tool_path}"/exec/git.R tabulate \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_commits_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"/gitlog_complete.csv
   Rscript "${kaiaulu_tool_path}"/exec/git.R tabulate \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"/gitlog_filtered.csv

   # Analyse entities with git blame.
   Rscript "${kaiaulu_tool_path}"/exec/git.R entity parallel \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"/gitlog_filtered.csv \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"/entities

   # Perform identity matching and post-processing.
   conda activate emse
   printf 'Processing data for %s with Kaiaulu...\n' "$project"
   python3 "$src_path"/process_kaiaulu.py \
      --project "$project" \
      --data_path "$kaiaulu_raw_data_path"/gitlog/"$project" \
      --conf_path "$kaiaulu_tool_path"/conf/foucault_"$project"_analysis.yml \
      --save_path "$kaiaulu_data_path"/"$project" \
      --merge_id \
      --time_slice

   # Prepare the developer networks constructed by Kaiaulu.
   conda activate kaiaulu
   echo "Constructing developer networks for project $project with Kaiaulu..."
   mkdir -p "$kaiaulu_data_path"/"$project"/networks
   i=1
   for d in "$kaiaulu_data_path"/"$project"/entities/*
     do
       range=$(basename "${d}")
       Rscript "$kaiaulu_tool_path"/exec/graph.R temporal entity \
         "$kaiaulu_tool_path"/tools.yml \
         "$kaiaulu_tool_path"/conf/foucault_"$project"_analysis.yml \
         "$kaiaulu_tool_path"/conf/foucault_"$project"_cli.yml \
         "$d/"entities_"$range".csv \
         "$kaiaulu_data_path"/"$project"/networks/range_"$i"_adjacency_matrix.csv
       ((i++))
     done
  done

# Analyse all subject projects (LTS branches) with Kaiaulu.
for project in ${project_list[*]}
  do
   conda activate kaiaulu
   printf 'Analysing %s with Kaiaulu...\n' "$project"
   # Analyse the git log.
   mkdir -p "${kaiaulu_raw_data_path}"/gitlog/"${project}"_bug/entities
   Rscript "${kaiaulu_tool_path}"/exec/git.R tabulate \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_commits_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"_bug/gitlog_complete.csv
   Rscript "${kaiaulu_tool_path}"/exec/git.R tabulate \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"_bug/gitlog_filtered.csv

   # Analyse entities with git blame.
   Rscript "${kaiaulu_tool_path}"/exec/git.R entity parallel \
     "${kaiaulu_tool_path}"/tools.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_analysis.yml \
     "${kaiaulu_tool_path}"/conf/foucault_"${project}"_bug_cli.yml \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"_bug/gitlog_filtered.csv \
     "${kaiaulu_raw_data_path}"/gitlog/"${project}"_bug/entities

   # Perform identity matching and post-processing.
   conda activate emse
   printf 'Processing data for %s with Kaiaulu...\n' "$project"
   python3 "$src_path"/process_kaiaulu.py \
      --project "$project"_bug \
      --data_path "$kaiaulu_raw_data_path"/gitlog/"$project"_bug \
      --conf_path "$kaiaulu_tool_path"/conf/foucault_"$project"_bug_analysis.yml \
      --save_path "$kaiaulu_data_path"/"$project"_bug \
      --merge_id \
      --time_slice

   # Prepare the developer networks constructed by Kaiaulu.
   conda activate kaiaulu
   echo "Constructing developer networks for project $project with Kaiaulu..."
   mkdir -p "$kaiaulu_data_path"/"$project"_bug/networks
   i=1
   for d in "$kaiaulu_data_path"/"$project"_bug/entities/*
     do
       range=$(basename "${d}")
       Rscript "$kaiaulu_tool_path"/exec/graph.R temporal entity \
         "$kaiaulu_tool_path"/tools.yml \
         "$kaiaulu_tool_path"/conf/foucault_"$project"_bug_analysis.yml \
         "$kaiaulu_tool_path"/conf/foucault_"$project"_bug_cli.yml \
         "$d/"entities_"$range".csv \
         "$kaiaulu_data_path"/"$project"_bug/networks/range_"$i"_adjacency_matrix.csv
       ((i++))
     done
  done

conda activate emse
python3 "$src_path"/turnover.py \
        --tool kaiaulu \
        --data_path "$kaiaulu_data_path" \
        --git_repo_path "$cloc_git_repo_path" \
        --bug_fix_path "$bug_fix_path" \
        --save_path "$res_path"/kaiaulu \
        --projects "$project_str_list"
