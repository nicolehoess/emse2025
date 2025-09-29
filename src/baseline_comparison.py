# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Compares the baseline data extracted by the mining tools
# Codeface, git2net, GrimoireLab and Kaiaulu.

import argparse
import git2net
import igraph as ig
import lizard
import mysql.connector
import numpy as np
import networkx as nx
import os
import pandas as pd
import pathpy as pp
import pydriller
from setuptools.command.develop import develop

import query_codeface
import query_kaiaulu
import query_git2net
import query_grimoire
import sqlite3
import yaml

from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from igraph import ARPACKOptions
from pygments import lexers


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True,
                        help="Tool the analysis was performed with. Supports"
                             "codeface, kaiaulu, git2net, grimoire.")
    parser.add_argument("--data_path", required=True,
                        help="Either path to the directory containing the parsed "
                             "git log (kaiaulu, git2net) or "
                             "database port (codeface, grimoire).")
    parser.add_argument("--save_path", required=True,
                        help="Path to the directory to store the results")
    # parser.add_argument("--git_repo_path", required=True,
    #                     help="Path to the directory containing the git repositories.")
    parser.add_argument("--projects", type=str, required=True,
                        help="List of projects to analyse")
    parser.add_argument("--studies", type=str, required=True,
                        help="List of studies the projects were analysed for")
    parser.add_argument("--conf_path", required=False,
                        help="Path to the configuration file (git2net, grimoire, kaiaulu).")
    parser.add_argument("--network_path", required=False,
                        help="Path to the directory containing the adjacency "
                             "matrices in CSV format constructed by the tool.")
    return parser.parse_args()


def main(tool, data_path, save_path, projects, studies, conf_path, network_path):
    # Get tool-specific meta data and range mapping.
    if tool == "codeface":
        con = mysql.connector.connect(
            host="127.0.0.1",
            database="codeface",
            user="codeface",
            password="codeface",
            port=str(data_path)
        )
        cur = con.cursor(buffered=True)
    if tool not in ["codeface", "kaiaulu", "git2net", "grimoire"]:
        print("Tool not supported. Choose between codeface, kaiaulu, "
              "git2net, grimoire.")
        return

    # Aggregate baseline data statistics.
    df_list = []

    projects = projects.split(", ")
    studies = studies.split(", ")
    i = 0
    for p in projects:
        print("Processing project "+p+"...")
        study = studies[i]
        study_author = study.split("_")[0]

        # Setup to get tool-specific project data
        if tool == "codeface":
            pid = query_codeface.get_project_id(cur, p)
            range_ids_tool = query_codeface.get_range_ids(cur, pid)
        elif tool == "kaiaulu":
            git_log_complete_path = os.path.join(data_path, study, tool, "procdata", p, "gitlog_complete.csv")
            df_git_log_complete = pd.read_csv(git_log_complete_path, encoding="latin-1")
            files_path = os.path.join(data_path, study, tool, "procdata", p, "files")
            entities_path = os.path.join(data_path, study, tool, "procdata", p, "entities")
            range_ids_tool = sorted([f for f in os.listdir(files_path) if f != ".DS_Store"])
        elif tool == "git2net":
            project_path = os.path.join(data_path, study, tool, p)
            db_path = os.path.join(project_path, p+"_line.db")
            con = sqlite3.connect(db_path)
            cur = con.cursor()
            block_project_path = os.path.join(data_path, "baseline", "git2net", p)
            block_db_path = os.path.join(block_project_path, p+"_block.db")
            con_block = sqlite3.connect(block_db_path)
            cur_block = con_block.cursor()
        elif tool == "grimoire":
            es = Elasticsearch(["http://elasticsearch:" + str(data_path)])
            es.indices.put_settings(body={"index": {"max_result_window": 500000}})

        if tool == "git2net" or tool == "grimoire":
            project_conf_path = os.path.join(conf_path, study_author+"_"+p+".yml")
            with open(project_conf_path) as file:
                conf = yaml.safe_load(file)
            ranges = conf["ranges"]
            range_ids_tool = range(0, len(ranges) - 1)
        elif tool == "kaiaulu":
            project_conf_path = os.path.join(conf_path, study_author+"_"+p+"_analysis.yml")
            with open(project_conf_path) as file:
                conf = yaml.safe_load(file)
            ranges = conf["analysis"]["window"]["ranges"]
            ranges = [d.strftime("%Y-%m-%d %H:%M:%S") for d in ranges]

        j = 0
        for r in range_ids_tool:
            # Get the number of commits, changed files, changed named
            # entities (functions, interfaces) and active developers in
            # the current time window.
            if tool == "codeface":
                commit_list = query_codeface.get_commits(cur, pid, r)
                commits = len(commit_list)
                files = query_codeface.get_num_files(cur, pid, r)
                entity_list = query_codeface.get_entities(cur, pid, r)
                entities = len(entity_list)
                devs = query_codeface.get_num_devs(cur, pid, r)
            elif tool == "git2net":
                commit_list = query_git2net.get_commits(cur, ranges[r], ranges[r+1])
                commits = len(commit_list)
                files = query_git2net.get_num_files(cur, ranges[r], ranges[r+1])
                entities = query_git2net.get_num_entities(cur_block, ranges[r], ranges[r+1])
                dev_list = query_git2net.get_devs(cur, ranges[r], ranges[r+1])
                devs = len(dev_list)
            elif tool == "grimoire":
                commit_list = query_grimoire.get_commits(es, p, ranges[r], ranges[r+1])
                commits = len(commit_list)
                files = query_grimoire.get_num_files(es, p, ranges[r], ranges[r+1])
                entities = None
                dev_list = query_grimoire.get_devs(es, p, ranges[r], ranges[r+1])
                devs = len(dev_list)
            else:  # Kaiaulu
                # Depending on the replication study a data set belongs to,
                # we cannot necessarily get all information from the already sliced data.
                # For instance, the sliced data is unfiltered for Gote et al.,
                # but already file-filtered for Foucault et al..
                # Therefore, we manually slice the complete git log table to be safe.
                df_git_log_slice = df_git_log_complete.loc[
                    (df_git_log_complete["committer_datetimetz"] >= ranges[j]) & (
                            df_git_log_complete["committer_datetimetz"] <= ranges[j+1])]
                range_file_name = "files_" + str(r) + ".csv"
                commits = query_kaiaulu.get_num_commits(df_git_log_slice)
                devs = query_kaiaulu.get_num_devs_replication(df_git_log_slice)

                # Get the files and entities from the sliced tables.
                range_file_name = "files_" + str(r) + ".csv"
                git_log_files_slice_file_path = os.path.join(files_path, str(r), range_file_name)
                df_git_log_files_slice = pd.read_csv(git_log_files_slice_file_path, encoding="latin-1")
                files = query_kaiaulu.get_num_files(df_git_log_files_slice)

                range_file_name = "entities_" + str(r) + ".csv"
                git_log_entities_slice_path = os.path.join(entities_path, str(r), range_file_name)
                df_git_log_entities_slice = pd.read_csv(git_log_entities_slice_path, encoding="latin-1")
                entities = len(df_git_log_entities_slice)

            entry = pd.DataFrame.from_dict({
                "tool": [tool],
                "project": [p],
                "range_id": [j+1],
                "Commits": [commits],
                "Files": [files],
                "Entities": [entities],
                "Developers": [devs]
            })
            df_list.append(entry)
            j += 1

        i += 1

    # Concat and store data set.
    df = pd.concat(df_list, ignore_index=False)
    if not os.path.isdir(save_path):
        os.makedirs(save_path)
    if tool == "codeface":
        if "birt" in projects or "conductor" in projects or "flink" in projects:
            df.to_csv(os.path.join(save_path, "statistics_gote.csv"), index=False)
        else:
            df.to_csv(os.path.join(save_path, "statistics_joblin.csv"), index=False)
    else:
        df.to_csv(os.path.join(save_path, "statistics.csv"), index=False)


if __name__ == "__main__":
    args = arguments()
    main(args.tool, args.data_path, args.save_path, args.projects,
         args.studies, args.conf_path, args.network_path)
