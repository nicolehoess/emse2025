# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Helper functions to query data from the GrimoireLab database.

from elasticsearch import Elasticsearch
from elasticsearch_dsl import Search
import pandas as pd


def get_devs(es, project, start_date, end_date):
    """
    Gets all active developers (authors) in a specific revision range of a project.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of active developers (author IDs).
    """

    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('range', commit_date={'gte': start_date,
                                       'lte': end_date})
    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    authors = []
    for r in result:
        authors.append(r["author_id"])
    return set(authors)



def get_dev_name(es, project, dev):
    """
    Gets the name of the given developer.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        dev: The author ID.

    Returns:
        The name of the developer.
    """

    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('term', author_id=dev)
    result = s.execute()

    name = result[0]["author_name"]
    if name is not None:
        name += " <"+dev+">"
    else:
        name = "<"+dev+">"
    return name


def get_commits(es, project, start_date, end_date):
    """
    Gets all commits authored in the given revision range.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The list of authored commits.
    """

    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('range', commit_date={'gte': start_date,
                                       'lte': end_date})

    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()
    hashes = [r["hash"] for r in result]
    return hashes


def get_dev_commits(es, project, start_date, end_date, dev):
    """
    Gets the number of commits authored by the given developer
    in the given revision range.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        dev: The author ID.

    Returns:
        The number of authored commits.
    """
        
    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('range', commit_date={'gte': start_date,
                                       'lte': end_date})
    s = s.filter('term', author_id=dev)
    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()
    return len(result)


def get_commit_date(es, project, hash):
    """
    Gets the date at which the given commit was committed to the
    repository.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        hash: The commit hash.

    Returns:
        The commit date.
    """
    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('term', hash=hash)

    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    if result is not None:
        return result[0]["commit_date"]
    else:
        return None


def get_commits_info(es, project, start_date, end_date):
    """
    Gets the commits authored by all developers in the given
    revision range, annotated with date and author.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of all authored commits with author and date.
    """
    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('range', commit_date={'gte': start_date,
                                       'lt': end_date})

    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    df_list = []
    for r in result:
        entry = pd.DataFrame.from_dict({
            "hash": [r["hash"]],
            "author": [r["author_id"]],
            "time": [r["commit_date"]]
        })
        df_list.append(entry)
    df = pd.concat(df_list, ignore_index=True)
    return df


def get_dev_diff_size(es, project, start_date, end_date, dev):
    """
    Gets the number of lines (added and removed) authored by a
    developer in a given revision range.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        dev: The author ID.

    Returns:
        The number of authored lines.
    """
    s = Search(using=es, index='git')
    s = s.filter('term', project=project)
    s = s.filter('range', commit_date={'gte': start_date,
                                       'lte': end_date})
    s = s.filter('term', author_id=dev)
    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    diff = 0
    for r in result:
        diff += r["lines_changed"]
    return diff

def get_edits_info(es, project, start_date, end_date):
    """
    Gets the file edits authored by all developers in the given
    revision range, annotated with date, author and modified lines.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        Annotated list of all authored file edits.
    """

    s = Search(using=es, index='git_areas_of_code')
    s = s.filter('term', project=project)
    s = s.filter('range', committer_date={'gte': start_date,
                                          'lt': end_date})
    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    df_list = []
    for r in result:
        entry = pd.DataFrame.from_dict({
            "developer": [r["author_id"]],
            "hash": [r["hash"]],
            "date": [r["committer_date"]],
            "file": [r["filepath"]],
            "churn": [r["addedlines"] + r["removedlines"]]
        })
        df_list.append(entry)
    df = pd.concat(df_list, ignore_index=True)
    return df


def get_num_files(es, project, start_date, end_date):
    """
    Gets the number of distinct files changed in the given
    revision range.

    Args:
        es: The ElasticSearch instance.
        project: The subject project.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The number of distinct changed files.
    """

    s = Search(using=es, index='git_areas_of_code')
    s = s.filter('term', project=project)
    s = s.filter('range', committer_date={'gte': start_date,
                                          'lte': end_date})
    cnt = s.count()
    s = s[0:cnt]
    result = s.execute()

    files = [r["filepath"] for r in result]
    num_files = len(list(set(files)))
    return num_files
