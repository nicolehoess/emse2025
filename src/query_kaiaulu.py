# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Helper functions to query data from the Kaiaulu tables,

import pandas as pd


def get_commits(df_git_log):
    """
    Gets all commit hashes.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        The list of commit hashes.
    """
    return df_git_log["commit_hash"].unique()


def get_num_commits(df_git_log):
    """
    Counts the number of commits.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of commits.
    """
    return len(df_git_log["commit_hash"].unique())


def get_commits_info(df_git_log, start_date, end_date):
    """
    Gets the commits authored by all developers in the given
    revision range, annotated with date and author.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of all authored commits with author and date.
    """

    df_git_log = df_git_log[["author_name_email", "commit_hash", "committer_datetimetz"]]
    date_mask = (df_git_log["committer_datetimetz"] >= start_date) & (df_git_log["committer_datetimetz"] < end_date)
    df_git_log = df_git_log.loc[date_mask]
    df_git_log = df_git_log.drop_duplicates()
    df_git_log = df_git_log.rename(columns={"commit_hash": "hash",
                                            "author_name_email": "author",
                                            "committer_datetimetz": "time"})
    return df_git_log


def get_edits_info(df_git_log, start_date, end_date):
    """
    Gets the file edits authored by all developers in the given
    revision range, annotated with date, author and modified lines.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        Annotated list of all authored file edits.
    """
    df_git_log = df_git_log[["author_name_email", "commit_hash",
                             "committer_datetimetz", "file_pathname",
                             "lines_added", "lines_removed"]].copy()
    df_git_log["committer_datetimetz"] = pd.to_datetime(df_git_log["committer_datetimetz"])
    date_mask = (df_git_log["committer_datetimetz"] >= start_date) & (df_git_log["committer_datetimetz"] < end_date)
    df_git_log = df_git_log.loc[date_mask]
    df_git_log["churn"] = df_git_log["lines_added"] + df_git_log["lines_removed"]
    df_git_log = df_git_log.rename(columns={"author_name_email": "developer",
                                            "commit_hash": "hash",
                                            "file_pathname": "file"})
    return df_git_log[["developer", "hash", "committer_datetimetz", "file", "churn"]]


def get_commit_date(df_git_log, hash):
    """
    Gets the date at which the given commit was committed to the
    repository.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.
        hash: The commit hash.

    Returns:
        The commit date.
    """
    df_git_log = df_git_log.loc[df_git_log["commit_hash"] == hash]
    if len(df_git_log) > 0:
        return df_git_log["committer_datetimetz"].iloc[0]
    else:
        return None


def get_num_files(df_git_log):
    """
    Counts the number of edited files.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of edited files.
    """
    return len(df_git_log["file_pathname"].unique())


def get_num_named_entities(df_git_log):
    """
    Counts the number of unique entities.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_entity_gitlog.

    Returns:
        Number of unique entities..
    """
    named_entities = list(df_git_log["entity_definition_name"].unique())
    n_named_entities = len(named_entities)
    return n_named_entities


def get_num_devs_prior(df_git_log, df_entity):
    """
    Counts the number of developers for the prior parameter setting.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.
        df_entity: The Kaiaulu git log from parse_entity_gitlog.

    Returns:
        Number of developers (for the prior parameter setting).
    """
    df_author = df_git_log[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_git_log[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_author, df_committer])

    # Search for additional identities in entity logs
    df_author = df_entity[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_entity[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_dev, df_author, df_committer])

    n_devs = len(list(df_dev["name_email"].unique()))
    return n_devs


def get_num_devs_replication(df_git_log):
    """
    Counts the number of developers for the reproduction parameter setting.

    Args:
        df_git_log: The Kaiaulu git log (slice) from parse_gitlog.

    Returns:
        Number of developers (for the reproduction parameter setting).
    """
    # Number of active developers
    df_author = df_git_log[["author_name_email"]]
    df_author = df_author.rename(
        columns={"author_name_email": "name_email"})
    df_committer = df_git_log[["committer_name_email"]]
    df_committer = df_committer.rename(
        columns={"committer_name_email": "name_email"})
    df_dev = pd.concat([df_author, df_committer])
    n_devs = len(list(df_dev["name_email"].unique()))
    return n_devs


def get_devs(df_git_log):
    """
    Gets all active developers (authors) in a specific revision range of a project.

    Args:
        df_git_log: Git log.

    Returns:
        List of active developers (authors).
    """

    authors = list(df_git_log["author_name_email"].unique())
    return authors


def get_dev_commits(df_git_log, dev):
    """
    Counts the number of commits authored by the given developer.

    Args:
        df_git_log: The Kaiaulu git log from parse_(entity)_gitlog (slice).
        dev: The developer identity.

    Returns:
        Number of commits the developer authored.
    """

    commits = df_git_log.loc[df_git_log["author_name_email"] == dev]
    unique_commits = list(set(commits["commit_hash"]))
    return len(unique_commits)


def get_dev_diff_from_gitlog(df, m):
    """
    Counts the number of line changes authored by the given developer based on
    Kaiaulu's parse_gitlog.

    Args:
        df: The Kaiaulu git log (slice) from parse_gitlog (slice).
        dev: The developer identity.

    Returns:
        Number of lines of code changes authored by the developer.
    """

    df_dev = df.loc[df["author_name_email"] == m]
    added = deleted = 0
    if not df_dev is None:
        added = sum(df_dev["lines_added"])
        deleted = sum(df_dev["lines_removed"])
    diff = added + deleted
    return diff


def get_dev_diff_from_entity_gitlog(df, m):
    """
    Counts the number of lines changes authored by the given developer based on
    Kaiaulu's parse_entity_gitlog.

    Args:
        df: The Kaiaulu git log from parse_entity_gitlog.
        dev: The developer identity.

    Returns:
        Number of lines of code changes authored by the developer.
    """

    df_dev = df.loc[df["author_name_email"] == m]
    diff = 0
    if not df_dev is None:
        diff = sum(df_dev["n_lines_changed"])
    return diff

