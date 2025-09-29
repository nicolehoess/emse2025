# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# This script replaces numeric or cryptic node names in the adjacency matrix with names.

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

from datetime import datetime
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from networkx.algorithms import bipartite


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--tool", required=True,
                        help="Tool that was used to construct the matrices (git2net/grimoire)")
    parser.add_argument("--data_path", required=True,
                        help="Either path to the directory containing the parsed "
                             "git log (git2net) or database port (grimoire).")
    parser.add_argument("--projects", type=str, required=True,
                        help="List of projects to analyse")
    parser.add_argument("--network_path", required=False,
                        help="Path to the adjacency matrices (only grimoire).")
    return parser.parse_args()


def main(tool: str, data_path: str, projects: str, network_path: str = None):
    projects = projects.split(", ")
    for p in projects:
        if tool == "git2net":
            project_path = os.path.join(data_path, p)
            db_path = os.path.join(project_path, p + "_line.db")
            con = sqlite3.connect(db_path)
            cur = con.cursor()
            network_path = os.path.join(project_path, "line", "coediting")
        elif tool == "grimoire":
            es = Elasticsearch(["http://elasticsearch:" + str(data_path)])
            es.indices.put_settings(body={"index": {"max_result_window": 500000}})
            network_path = os.path.join(network_path, p, "networks")
        else:
            print("Tool not supported.")
            return

        files = [f for f in os.listdir(network_path)]
        for f in files:
            f_path = os.path.join(network_path, f)
            f_path_with_names = f_path.split(".csv")[0] + "_with_names.csv"
            print(f_path_with_names)

            # if "with_names" in f_path:
            #     os.remove(f_path)

            if "edgelist" in f:
                # We only have edgelists for git2net.
                df = pd.read_csv(f_path)
                source_devs = list(df["source"].unique())
                target_devs = list(df["target"].unique())
                dev_list = list(set(source_devs+target_devs))
                for dev in dev_list:
                    dev_name = query_git2net.get_dev_name(cur, dev)
                    df["source"] = df["source"].replace(dev, dev_name)
                    df["target"] = df["target"].replace(dev, dev_name)
                df.to_csv(f_path_with_names, index=False)
            elif "adjacency" in f:
                df = pd.read_csv(f_path, index_col=0)
                df.index = df.index.map(str)
                for dev in list(df.columns):
                    if tool == "git2net":
                        dev_name = query_git2net.get_dev_name(cur, dev)
                    else: # GrimoireLab
                        dev_name = query_grimoire.get_dev_name(es, p, dev)
                    df.index = df.index.to_series().replace({str(dev): dev_name})
                    df = df.rename(columns={dev: dev_name})
                df.to_csv(f_path_with_names, index=True)


if __name__ == "__main__":
    args = arguments()
    main(args.tool, args.data_path, args.projects, args.network_path)
