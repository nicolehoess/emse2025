# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Classifies developers into core and peripheral to replicate Joblin et al., 2017.
# Requires the input data to be time sliced into three-month intervals.
# Requires the adjacency matrices of constructed developer networks in CSV format.

import argparse
import igraph as ig
import mysql.connector
import numpy as np
import networkx as nx
import os
import pandas as pd
import query_codeface
import query_kaiaulu
import query_git2net
import query_grimoire
import sqlite3
import yaml

from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from igraph import ARPACKOptions

def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True,
                        help="Tool the analysis was performed with. Supports"
                             "codeface, kaiaulu, git2net, grimoire.")
    parser.add_argument("--project", required=True,
                        help="Name of the analysed subject project.")
    parser.add_argument("--data_path", required=True,
                        help="Either path to the directory containing the parsed "
                             "git log (kaiaulu, git2net and grimoire) or "
                             "database port (codeface).")
    parser.add_argument("--network_path", required=True,
                        help="Path to the directory containing the adjacency "
                             "matrices in CSV format constructed by the tool.")
    parser.add_argument("--save_path", required=True,
                        help="Path to the directory to store the classification "
                             "results")
    parser.add_argument("--conf_path", required=False,
                        help="Path to the configuration file (git2net).")
    return parser.parse_args()


def classify_developers(metric, threshold):
    """
    Classify developers in the given data frame based on the specified metric
    column.

    Args:
        metric: A pandas series of metric values for each developer.
        threshold: The threshold to apply.

    Returns:
        The data frame with a new label column.
    """

    col_threshold = metric.quantile(threshold)
    # Developers which are not above the threshold are classified as peripheral.
    metric = metric.where(metric > col_threshold, "peripheral")
    # The other developers are core developers.
    metric = metric.where(metric == "peripheral", "core")
    return metric


def label_developers(df, threshold):
    """
    Classifies developers into core and peripheral based on each of the given
    metrics in the metrics data frame.

    Args:
        df: A data frame (for a specific time interval) with developer and
            metrics columns.
        threshold: The threshold to apply.

    Returns:
        The labeled data frame with core and peripheral developers.
    """

    metric_cols = ["loc_count", "commit_count", "degree", "eigenvector", "hierarchy"]
    for c in metric_cols:
        class_col = c+"_class"
        df[class_col] = classify_developers(df[c].astype("float64"), threshold)
    return df


def calculate_statistics(range_id, df):
    """
    Calculates statistics on the core developer classification characteristics
    in a specific range.

    Args:
        range_id: ID of the time interval under analysis.
        df: A data frame (for a specific time interval) with developer
            classifications.

    Returns:
        A data frame with statistics for the given time interval.
    """

    # Different projects may have different contribution conventions,
    # e.g. in terms of the diff size of a commit. We consider the median and
    # maximum diff size as well as the commits with more than
    # 1ß00 changed lines.
    loc_per_commit = df["loc_count"]/df["commit_count"]
    mean_loc_per_commit = np.mean(loc_per_commit)
    max_loc_per_commit = np.max(loc_per_commit)
    num_high_loc_per_commit = len(loc_per_commit.index[
        loc_per_commit > 1000].tolist())
    ratio_high_loc_per_commit = num_high_loc_per_commit/len(loc_per_commit)

    # Due to the large discrepancies in LOC and other core developer metrics
    # agreement observed in project GTK, we also search for developers
    # that are only core developers based on LOC count.
    loc_core_only_mask = (df["loc_count_class"] == "core")
    num_loc_count = len(df.loc[loc_core_only_mask])

    # We also calculate the ratio of core developers that were identified
    # by LOC count and another metric vs those identified by LOC count only.
    any_core_mask = (df["loc_count_class"] == "core") & ((
            df["degree_class"] == "core") | (
            df["eigenvector_class"] == "core") | (
            df["hierarchy_class"] == "core"))
    df_any_core = df.loc[any_core_mask]
    num_any_core = len(df_any_core)
    ratio_multiple_metrics = 0
    if num_loc_count > 0:
        ratio_multiple_metrics = num_any_core/num_loc_count

    entry = pd.DataFrame.from_dict({
        "range_id": [range_id],
        "mean_loc_per_commit": [mean_loc_per_commit],
        "max_loc_per_commit": [max_loc_per_commit],
        "num_high_loc_per_commit": [num_high_loc_per_commit],
        "ratio_high_loc_per_commit": [ratio_high_loc_per_commit],
        "num_loc_count_only": [num_loc_count],
        "ratio_loc_and_network": [ratio_multiple_metrics]})
    return entry


def core_dev_diagnostics(df, save_path):
    """
    Analyses core developer characteristics in the subject project to
    reason about potential discrepancies.

    Args:
        df: The data frame with developer classifications.
        save_path: The path to the file to store the statistics.

    Returns:
        Nothing.
    """

    df_statistics = []
    range_ids = list(df["range_id"].unique())
    for r in range_ids:
        df_range = df.loc[df["range_id"] == r]
        if len(df_range) > 0:
            entry = calculate_statistics(r, df_range)
            df_statistics.append(entry)

    # Concat data frames.
    df_statistics = pd.concat(df_statistics, ignore_index=True)
    df_statistics.loc["mean"] = df_statistics.mean(numeric_only=True)

    # Save the metrics data set.
    df_statistics.to_csv(save_path, index=True)


def main(tool, project, data_path, network_path, save_path, conf_path):
    # Data frame containing developer classifications based on different
    # metrics for all ranges.
    df_list = []

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
        pid = query_codeface.get_project_id(cur, project)
        range_ids_tool = query_codeface.get_range_ids(cur, pid)
    elif tool == "kaiaulu":
        files_path = os.path.join(data_path, "files")
        range_ids_tool = sorted(os.listdir(files_path))
    elif tool == "git2net":
        con = sqlite3.connect(data_path)
        cur = con.cursor()
        with open(conf_path) as file:
            conf = yaml.safe_load(file)
        ranges = conf["ranges"]
        range_ids_tool = range(0, len(ranges)-1)
        print("number of ranges:"+str(len(ranges)))
    elif tool == "grimoire":
        with open(conf_path) as file:
            conf = yaml.safe_load(file)
        ranges = conf["ranges"]
        range_ids_tool = range(0, len(ranges)-1)
        es = Elasticsearch(["http://elasticsearch:"+str(data_path)])
        es.indices.put_settings(body={"index": {"max_result_window": 500000}})
        if project == "llvm-project":
            project = "llvm"
    else:
        print("Tool not supported. Choose between codeface, kaiaulu, "
              "git2net, grimoire.")
        return

    range_id_norm = 1
    for r in range_ids_tool:
        df_range_list = []

        # Get all developers who contributed in a range.
        if tool == "codeface":
            developers = query_codeface.get_devs(cur, pid, r)
        elif tool == "kaiaulu":
            range_file_name = "files_" + str(r) + ".csv"
            git_log_slice_file_path = os.path.join(files_path, str(r),
                                                   range_file_name)
            df_git_log_slice = pd.read_csv(git_log_slice_file_path,
                                           encoding="latin-1")

            # Get all developers who contributed in a range.
            developers = query_kaiaulu.get_devs(df_git_log_slice)
        elif tool == "git2net":
            print("range "+str(r)+" start: "+str(ranges[r])+" end: "+str(ranges[r+1]))
            developers = query_git2net.get_devs(cur, ranges[r], ranges[r+1])
        else:
            print("range "+str(r)+" start: "+str(ranges[r])+" end: "+str(ranges[r+1]))
            developers = query_grimoire.get_devs(es, project, ranges[r], ranges[r+1])

        # Network metrics
        adj_path = os.path.join(network_path,
                                "range_" + str(range_id_norm) + "_adjacency_matrix.csv")
        try:
            adj_matrix = pd.read_csv(adj_path, encoding="latin-1", index_col=0)  # latin-1 required for Kaiaulu
            adj_matrix.index = adj_matrix.index.map(str)
            G_nx = nx.from_pandas_adjacency(adj_matrix, nx.DiGraph())
            G = ig.Graph.from_networkx(G_nx)
            G.vs["name"] = list(G_nx.nodes())
            # Convert graph to undirected and simplify it as done by Codeface.
            # By working with an undirected graph, we also do not have to
            # account for different edge directions calculated by git2net.
            G = G.as_undirected()
            G.simplify()
        except:
            # Some tools do not return an empty adjacency matrix.
            print("Adjacency matrix empty.")
            G_nx = nx.empty_graph(n=0)
            G = ig.Graph.from_networkx(G_nx)
            G.vs["name"] = list(G_nx.nodes())

        # Default values for network metrics
        eigenvector_cent = np.nan
        if not (G.vcount() == 0 and G.ecount() == 0):
            options = ARPACKOptions()
            options.maxiter = 1000000
            eigenvector_cent = G.eigenvector_centrality(arpack_options=options)

        for dev in developers:
            # Count-based metrics‚
            if tool == "codeface":
                loc_count = query_codeface.get_dev_diff_size(cur, pid, r, dev)
                commit_count = query_codeface.get_dev_commits(cur, pid, r, dev)
            elif tool == "kaiaulu":
                loc_count = query_kaiaulu.get_dev_diff_from_gitlog(df_git_log_slice, dev)
                commit_count = query_kaiaulu.get_dev_commits(df_git_log_slice, dev)
            elif tool == "git2net":
                loc_count = query_git2net.get_dev_diff_size(cur, ranges[r], ranges[r+1], dev)
                commit_count = query_git2net.get_dev_commits(cur, ranges[r], ranges[r+1], dev)
            else:
                loc_count = query_grimoire.get_dev_diff_size(es, project, ranges[r], ranges[r+1], dev)
                commit_count = query_grimoire.get_dev_commits(es, project, ranges[r], ranges[r+1], dev)

            # Network-based metrics
            deg = 0
            cc = np.nan
            ev_cent = np.nan
            hierarchy = 0  # default in Codeface
            if not (G.vcount() == 0 and G.ecount() == 0) and dev in G.vs["name"]:
                dev_idx = G.vs.find(name=dev).index
                deg = G.degree(dev_idx)
                ev_cent = eigenvector_cent[dev_idx]
                cc = G.transitivity_local_undirected(vertices=[dev_idx], mode="nan")[0]
                if cc != 0:
                    hierarchy = deg / cc # formula from Codeface

            # Add sample to dataset
            if tool == "codeface":
                dev = query_codeface.get_dev_name(cur, dev)
            elif tool == "git2net":
                dev = query_git2net.get_dev_name(cur, dev)
            elif tool == "grimoire":
                dev = query_grimoire.get_dev_name(es, project, dev)

            entry = pd.DataFrame.from_dict({
                "range_id": [range_id_norm],
                "developer": [dev],
                "loc_count": [loc_count],
                "commit_count": [commit_count],
                "degree": [deg],
                "clustering_coefficient": [cc],
                "eigenvector": [ev_cent],
                "hierarchy": [hierarchy]})

            df_range_list.append(entry)

        # Assemble a data frame for the time interval and classify developers
        # who contributed in this range based on the metrics.
        if len(df_range_list) > 0:
            df_range_list = pd.concat(df_range_list, ignore_index=True)
            df_range_list = label_developers(df_range_list, threshold=0.8)
            df_list.append(df_range_list)

        range_id_norm += 1

    # Concat data frames.
    df = pd.concat(df_list, ignore_index=True)

    # Save the metrics data set.
    if not os.path.isdir(save_path):
        os.makedirs(save_path)
    save_file_path = os.path.join(save_path, "developer_classification.csv")
    df.to_csv(save_file_path, index=False)

    # Analyse additional characteristics.
    save_file_path = os.path.join(save_path, "developer_classification_characteristics.csv")
    core_dev_diagnostics(df, save_file_path)


if __name__ == "__main__":
    args = arguments()
    main(args.tool, args.project, args.data_path, args.network_path, args.save_path, args.conf_path)
