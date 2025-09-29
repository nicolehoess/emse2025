# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Constructs the developer networks from GrimoireLab in a suitable format for comparison.

import argparse
import networkx as nx
import pandas as pd
import os
import re
import yaml

from datetime import datetime
from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
from networkx.algorithms import bipartite


def arguments():
    """Define command line options."""
    parser = argparse.ArgumentParser()
    parser.add_argument("--conf_path", required=True, help="Path to the project \
                        configuration file")
    parser.add_argument("--network_path", required=True, help="Path to store \
                        the preprocessed adjacency matrices")
    return parser.parse_args()


def aggregate_range_data(es, project, start_date, end_date):
    """
    Get the number of changes made per developer and file in the given project
    during the given time range.

    Args:
        es: ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The aggregated data frame with developer ID, file and changes.
    """

    # Filter ElasticSearch index.
    s = Search(using=es, index='git_areas_of_code')
    s = s.filter('term', project=project)
    s = s.filter('range', committer_date={'gte': start_date,
                                          'lte': end_date})
    cnt = s.count()
    # Aggregate data per developer and file.
    s.aggs.bucket('by_authors', 'terms', field='author_id', size=cnt) \
        .bucket('by_filepath', 'terms', field="filepath", size=cnt) \
        .metric('author_file_edit_count', 'value_count', field='filepath')
    s = s.sort("author_id")

    # Parse the result to data frame.
    result = s.execute()
    author_buckets = result['aggregations']['by_authors']['buckets']
    author_data = []
    for author_bucket in author_buckets:
        file_buckets = author_bucket['by_filepath']['buckets']
        for file_bucket in file_buckets:
            author_file_changes = file_bucket['author_file_edit_count']['value']
            entry = {
                'author_id': author_bucket['key'],
                'filepath': file_bucket['key'],
                'count': author_file_changes
            }
            author_data.append(entry)
    df = pd.DataFrame.from_records(author_data)
    df = df.sort_values(by='author_id', ascending=False)
    return df


def file_count(G, u, v):
    """
    Calculate the edge weight connecting two developers u and v in the
    bipartite graph projection based on the number of jointly edited files.

    Args:
        G: The bipartite graph.
        u: First developer.
        v: Second developer.

    Returns:
        The edge weight.
    """

    w = 0
    for nbr in set(G[u]) & set(G[v]):
        w += 1
    return w


def weighted_file_count(G, u, v):
    """
    Calculate the edge weight connecting two developers u and v in the
    bipartite graph projection based on the number of jointly edited files,
    weighted by the number of changes made by the respective developer. This
    should note the level of interested in a common topic.

    Args:
        G: The bipartite graph.
        u: First developer.
        v: Second developer.

    Returns:
        The edge weight.
    """

    w = 0
    for n in set(G[u]) & set(G[v]):
        w += G[u][n].get("weight", 1) + G[v][n].get("weight", 1)
    return w


def main(conf_path: str, network_path: str = None):
    # Load configuration.
    with open(conf_path) as file:
        conf = yaml.safe_load(file)
    project = conf["project"]
    ranges = conf["ranges"]
    range_ids_tool = range(0, len(ranges) - 1)

    if not os.path.isdir(network_path):
        os.makedirs(network_path)

    # Initialise ElasticSearch.
    es = Elasticsearch(["http://elasticsearch:9200"])
    es.indices.put_settings(body={"index": {"max_result_window": 500000}})

    # Export data from ElasticSearch: Aggregate the number of changes to
    # files per developer and time window.
    for r in range_ids_tool:
        df = aggregate_range_data(es, project, ranges[r], ranges[r + 1])
        save_file_path = os.path.join(network_path, "range_" + str(r + 1) + "_export.csv")
        df.to_csv(save_file_path)

    # Construct the developer network for each time window.
    files = [f for f in os.listdir(network_path)]
    for f in files:
        # Convert each network export from GrimoireLab.
        if f.endswith("export.csv"):
            prefix = f.split("export.csv")[0]
            df = pd.read_csv(os.path.join(network_path, f),
                             names=["author_id", "filepath", "count"],
                             header=0)
            G = nx.Graph()

            # Add nodes for the bipartite graph.
            u = df["author_id"].unique()
            v = df["filepath"].unique()
            G.add_nodes_from(u, bipartite=0)
            G.add_nodes_from(v, bipartite=1)

            # Add weighted edges from authors to files.
            for idx, row in df.iterrows():
                G.add_edge(row["author_id"], row["filepath"],
                           weight=row["count"])

            # Construct bipartite projection.
            P = bipartite.generic_weighted_projected_graph(G, nodes=u, weight_function=weighted_file_count)

            # Save as adjacency matrix.
            adj = nx.convert_matrix.to_pandas_adjacency(P)
            save_file_path = os.path.join(network_path, prefix + "adjacency_matrix.csv")
            print(save_file_path)
            adj.to_csv(save_file_path)


if __name__ == "__main__":
    args = arguments()
    main(args.conf_path, args.network_path)
