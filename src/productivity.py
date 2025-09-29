# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# This script calculates productivity metrics to replicate Gote et al., 2022.

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
                             "git log (kaiaulu, git2net and grimoire) or "
                             "database port (codeface).")
    parser.add_argument("--save_path", required=True,
                        help="Path to the directory to store the results")
    parser.add_argument("--git_repo_path", required=True,
                        help="Path to the directory containing the git repositories.")
    parser.add_argument("--projects", type=str, required=True,
                        help="List of projects to analyse")
    parser.add_argument("--conf_path", required=False,
                        help="Path to the configuration file (git2net).")
    parser.add_argument("--network_path", required=False,
                        help="Path to the directory containing the adjacency "
                             "matrices in CSV format constructed by the tool.")
    parser.add_argument("--network_mode", required=False,
                        help="For git2net, the network format for network metrics "
                             "calculation. Supports edgelist and adjacency.")
    return parser.parse_args()


def compute_function_delta(git_repo, commit_hash):
    """
    Calculates the absolute delta in the total number of functions in
    a file (!= number of modified functions) for all files edited in a
    commit
    .
    The implementation is close to git2net's complexity pipeline, which
    uses pydriller to get the previous and new source code and lizard
    to calculate code-level metrics:
    https://github.com/gotec/git2net/blob/main/git2net/complexity.py

    Args:
        git_repo: The pydriller representation of a git repository.
        commit_hash: The commit for which to extract source code (files and functions) for.

    Returns:
        The aggregated delta in functions during that range.
    """

    try:
        pydriller_commit = git_repo.get_commit(commit_hash)

        delta = []
        for file in pydriller_commit.modified_files:
            # Calculate complexity metrics with lizard.
            # Other possible metrics from lizard:
            # l_pre.ccn (cyclomatic complexity)
            # l_pre.token_count
            # l_pre.nloc

            if file.old_path is not None:
                l_pre = lizard.analyze_file.analyze_source_code(file.old_path, file.source_code_before)
                pre = len(l_pre.function_list)
            else:
                pre = 0
            if file.new_path is not None:
                l_post = lizard.analyze_file.analyze_source_code(file.new_path, file.source_code)
                post = len(l_post.function_list)
            else:
                post = 0
            #delta += post-pre # np.abs(post-pre)
            delta.append(post-pre)
        delta = sum(np.abs(delta))
        return delta
    except:
        return 0


def compute_file_halstead_effort(filename, source_code):
    """
    Computes the Halstead effort
    (https://en.wikipedia.org/wiki/Halstead_complexity_measures)
    for a given pydriller modification object based on an algorithm
    adapted from https://github.com/priv-kweihmann/multimetric.

    The entire function originates from git2net:
    https://github.com/gotec/git2net/blob/main/git2net/complexity.py#L15

     Args:
         filename: The file name to determine an appropriate language parser.
         source_code: The source code to inspect.

     Returns:
         The Halstead effort.
    """

    _needles_operators = [
        "Token.Name.Class",
        "Token.Name.Decorator",
        "Token.Name.Entity",
        "Token.Name.Exception",
        "Token.Name.Function.Magic",
        "Token.Name.Function",
        "Token.Name.Label",
        "Token.Name.Tag",
        "Token.Operator.Word",
        "Token.Operator",
        "Token.Punctuation",
        "Token.String.Affix",
        "Token.String.Delimiter"]

    _needles_operands = [
        "Token.Literal.Date",
        "Token.Literal.String.Double",
        "Token.Literal.String",
        "Token.Literal.Number.Bin",
        "Token.Literal.Number.Float",
        "Token.Literal.Number.Hex",
        "Token.Literal.Number.Integer.Long",
        "Token.Literal.Number.Integer",
        "Token.Literal.Number.Oct",
        "Token.Literal.Number",
        "Token.Name",
        "Token.Name.Attribute",
        "Token.Name.Builtin.Pseudo",
        "Token.Name.Builtin",
        "Token.Name.Constant",
        "Token.Name.Variable.Class",
        "Token.Name.Variable.Global",
        "Token.Name.Variable.Instance",
        "Token.Name.Variable.Magic",
        "Token.Name.Variable",
        "Token.Name.Other",
        "Token.Number.Bin",
        "Token.Number.Float",
        "Token.Number.Hex",
        "Token.Number.Integer.Long",
        "Token.Number.Integer",
        "Token.Number.Oct",
        "Token.Number",
        "Token.String.Char",
        "Token.String.Double",
        "Token.String.Escape",
        "Token.String.Heredoc",
        "Token.String.Interpol",
        "Token.String.Other",
        "Token.String.Regex",
        "Token.String.Single",
        "Token.String.Symbol"]

    # Initialise a lexer for the programming language identified from m.filename.
    try:
        _lexer = lexers.get_lexer_for_filename(filename)
    except lexers.ClassNotFound:
        # Often, there is no lexer for the file.
        return 0

    # Parse the source code before the change.
    tokens = list(_lexer.get_tokens(source_code))

    # Count the number of operators
    operators_counter = [str(x[1]) for x in tokens if str(x[0]) in _needles_operators]
    eta_1 = max(1, len(set(operators_counter)))
    N_1 = max(1, len(operators_counter))

    # Count the number of operands.
    operands_counter = [str(x[1]) for x in tokens if str(x[0]) in _needles_operands]
    eta_2 = max(1, len(set(operands_counter)))
    N_2 = max(1, len(operands_counter))

    # Compute the Halstead effort based on these values.
    HE = (eta_1/2 * N_2/eta_2) * ((N_1+N_2) * np.log2(eta_1+eta_2))

    return HE


def compute_halstead_effort(git_repo, commit_hash):
    """
    Calculates the Halstead effort for all files edited in a commit.

    Uses the calculation implemented byf git2net
    (see compute_file_halstead_effort).

    Args:
        git_repo: The pydriller representation of a git repository.
        commit_hash: The commit for which to extract source code (files and functions) for.

    Returns:
        The aggregated Halstead effort during that range.
    """

    try:
        pydriller_commit = git_repo.get_commit(commit_hash)

        delta = []
        for file in pydriller_commit.modified_files:
            if file.old_path is not None:
                pre = compute_file_halstead_effort(file.old_path, file.source_code_before)
            else:
                pre = 0
            if file.new_path is not None:
                post = compute_file_halstead_effort(file.new_path, file.source_code)
            else:
                post = 0
            #delta += post-pre #np.abs(post-pre)
            delta.append(post-pre)

        return sum(np.abs(delta))
    except:
    	# Error in commit fetch or halstead calculation (e.g. because of unsupported file).
    	return 0


def main(tool, data_path, save_path, git_repo_path, projects, conf_path, network_path, mode):
    # Data frame containing productivity metrics for all projects and ranges.
    df_project_list = []

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

    projects = projects.split(", ")
    for p in projects:
        df_range_list = []

        # Setup to get tool-specific project data
        if tool == "codeface":
            pid = query_codeface.get_project_id(cur, p)
            range_ids_tool = query_codeface.get_range_ids(cur, pid)
        elif tool == "kaiaulu":
            files_path = os.path.join(data_path, p, "files")
            range_ids_tool = sorted(os.listdir(files_path))
        elif tool == "git2net":
            project_path = os.path.join(data_path, p)
            db_path = os.path.join(project_path, p+"_line.db")
            con = sqlite3.connect(db_path)
            cur = con.cursor()
        elif tool == "grimoire":
            es = Elasticsearch(["http://elasticsearch:" + str(data_path)])
            es.indices.put_settings(body={"index": {"max_result_window": 500000}})

        if tool == "git2net" or tool == "grimoire":
            project_conf_path = os.path.join(conf_path, "gote_"+p+".yml")
            with open(project_conf_path) as file:
                conf = yaml.safe_load(file)
            ranges = conf["ranges"]
            range_ids_tool = range(0, len(ranges) - 1)

        # Set up pydriller repository to calculate code-level metrics.
        git_repo_project_path = os.path.join(git_repo_path, p)
        pydriller_repo = pydriller.Git(git_repo_project_path)

        range_id_norm = 1
        for r in range_ids_tool:
            print("Processing "+p+", range "+str(r)+"...")
            # Calculate team size and number of commits.
            # Team size: Number of developers who committed within the time window.
            # Commits: Number of commits authored within a time window.
            if tool == "codeface":
                team_size = len(query_codeface.get_devs(cur, pid, r))
                commit_list = query_codeface.get_commits(cur, pid, r)
            elif tool == "git2net":
                team_size = len(query_git2net.get_devs(cur, ranges[r], ranges[r+1]))
                commit_list = query_git2net.get_commits(cur, ranges[r], ranges[r+1])
            elif tool == "grimoire":
                team_size = len(query_grimoire.get_devs(es, p, ranges[r], ranges[r+1]))
                commit_list = query_grimoire.get_commits(es, p, ranges[r], ranges[r+1])
            else:
                range_file_name = "files_" + str(r) + ".csv"
                git_log_slice_file_path = os.path.join(files_path, str(r),
                                                       range_file_name)
                df_git_log_slice = pd.read_csv(git_log_slice_file_path,
                                               encoding="latin-1")
                team_size = len(query_kaiaulu.get_devs(df_git_log_slice))
                commit_list = query_kaiaulu.get_commits(df_git_log_slice)

            # Normalise commits.
            commits = len(commit_list) / team_size

            # Calculate code-level productivity metrics.
            # Function delta: change in the total number of functions in all files
            # between two versions.
            # Halstead effort: change in the Halstead effort in all files
            # between two versions.
            function_delta_sum = 0
            halstead_delta_sum = 0
            for commit_hash in commit_list:
                function_delta_sum += compute_function_delta(pydriller_repo, commit_hash)
                halstead_delta_sum += compute_halstead_effort(pydriller_repo, commit_hash)

            # Calculate team-level metrics.
            function_delta = function_delta_sum / team_size
            halstead_delta = halstead_delta_sum / team_size

            # Calculate network metrics.
            if tool == "git2net" and mode == "edgelist":
                project_network_path = os.path.join(data_path, p, "line", "coediting")
                edgelist_path = os.path.join(project_network_path,
                                             "range_" + str(range_id_norm) + "_edgelist.csv")

                G = nx.MultiDiGraph()  # or MultiDiGraph if directed
                try:
                    with open(edgelist_path, newline='') as f:
                        reader = csv.DictReader(f)
                        for row in reader:
                            G.add_edge(
                                row['source'],
                                row['target'],
                                key=int(row['key']),
                                time=int(row['time'])
                            )
                except:
                    # Some tools do not return an empty adjacency matrix.
                    print("Adjacency matrix empty.")
                    G = nx.empty_graph(n=0)
            else:
                if tool == "codeface":
                    project_network_path = os.path.join(network_path, p)
                elif tool == "git2net" and mode == "adjacency":
                    project_network_path = os.path.join(data_path, p, "line", "coediting")
                elif tool == "grimoire":
                    project_network_path = os.path.join(network_path, p, "networks")
                else:
                    project_network_path = os.path.join(data_path, p, "networks")
                adj_path = os.path.join(project_network_path,
                                        "range_" + str(range_id_norm) + "_adjacency_matrix.csv")
                try:
                    adj_matrix = pd.read_csv(adj_path, encoding="latin-1", index_col=0)  # latin-1 required for Kaiaulu
                    adj_matrix.index = adj_matrix.index.map(str)
                    G = nx.from_pandas_adjacency(adj_matrix, nx.DiGraph())

                    # git2net, the original study tool, interprets edges as changes
                    # of authorship. If developer B changes code of developer A
                    # consequently results in an edge A->B.
                    # Contrary, Codeface and Kaiaulu interpret edges as
                    # contributions of one developer to another developer.
                    # Consequently, if developer B changes code of developer A,
                    # the edge goes in the opposite direction B->A.
                    # To replicate the logic from git2net, we h reverse these
                    # networks (same nodes, opposite edge direction).
                    if tool in ["codeface", "kaiaulu"]:
                        G = G.reverse()
                except:
                    # Some tools do not return an empty adjacency matrix.
                    print("Adjacency matrix empty.")
                    G = nx.empty_graph(n=0)

            # Number of nodes.
            nodes=len(G.nodes)

            # Calculate indegree and foreign modification ratio.
            # Note that we also use this for GrimoireLab, which actually returns
            # an undirected graph. In this case, networkx falls back to normal
            # degree. We decided to keep these values for completeness,
            # although they may overestimate indegree and FModR.
            indegree_list = []
            fmodr_list = []
            for n in G.nodes:
                # Unweighted indegree.
                indegree = G.in_degree(n)
                indegree_list.append(indegree)

                # Foreign edits are all ingoing edges that are not self-loops.
                in_edges = G.in_edges(n)
                self_loops = sum(1 for u, v in in_edges if u == v)
                foreign_edits = indegree-self_loops

                if indegree > 0:
                    fmodr = foreign_edits/indegree
                    fmodr_list.append(fmodr)
                else:
                    # We consider developers without any edges as such
                    # who did not edit foreign code.
                    fmodr_list.append(0)

            # Calculate team-level metrics.
            if len(indegree_list) > 0:
                indegree = np.mean(indegree_list)
            else:
                indegree = 0
            if len(fmodr_list) > 0:
                fmodr = np.mean(fmodr_list)
            else:
                fmodr = 0

            # Add sample to dataset.
            entry = pd.DataFrame.from_dict({
                "project": [p],
                "range_id": [range_id_norm],
                "commits": [commits],
                "function_delta": [function_delta],
                "halstead_delta": [halstead_delta],
                "team_size": [team_size],
                "nodes": [nodes],
                "indegree": [indegree],
                "fmodr": [fmodr]
            })

            # Assemble a data frame for the time interval.
            df_range_list.append(entry)
            range_id_norm += 1

        # Concat data frames.
        df_project = pd.concat(df_range_list, ignore_index=True)
        if not os.path.isdir(save_path):
            os.makedirs(save_path)
        if tool == "git2net" and mode == "edgelist":
            df_project.to_csv(os.path.join(save_path, "productivity_"+p+"_edgelist.csv"), index=False)
        else:
            df_project.to_csv(os.path.join(save_path, "productivity_"+p+".csv"), index=False)
        df_project_list.append(df_project)

    df = pd.concat(df_project_list, ignore_index=False)

    # Save the metrics data set.
    if not os.path.isdir(save_path):
        os.makedirs(save_path)
    if tool == "git2net" and mode == "edgelist":
        save_file_path = os.path.join(save_path, "productivity_edgelist.csv")
    else:
        save_file_path = os.path.join(save_path, "productivity.csv")
    df.to_csv(save_file_path, index=False)


if __name__ == "__main__":
    args = arguments()
    main(args.tool, args.data_path, args.save_path, args.git_repo_path,
         args.projects, args.conf_path, args.network_path, args.network_mode)
