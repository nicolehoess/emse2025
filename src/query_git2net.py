# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Helper functions to query data from the git2net database.

import pandas as pd
import sqlite3


def get_devs(cur, start_date, end_date):
    """
    Gets all active developers (authors) in a specific revision range of a project.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of active developers (author IDs).
    """

    query = "select distinct author_id \
             from commits \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<='"+str(end_date)+"'"
    cur.execute(query)
    res = cur.fetchall()

    devs = []
    for r in res:
        devs.append(str(r[0]))
    return devs


def get_dev_name(cur, dev):
    """
    Gets the name of the given developer.

    Args:
        cur: The SQLite database connection cursor.
        dev: The author ID.

    Returns:
        The name of the developer.
    """
    query = "select distinct author_name, author_email from commits \
             where author_id="+str(dev)
    cur.execute(query)
    res = cur.fetchall()
    name = ""
    for r in res:
        if name == "":
            name = r[0]

        if not "<" in name:
            # First e-mail address
            name += " <"+r[1]+">"
        else:
            # Second+ e-mail address
            name += " | <"+r[1]+">"
    return name


def get_commit_date(cur, hash):
    """
    Gets the date at which the given commit was committed to the
    repository.

    Args:
        cur: The SQLite database connection cursor.
        hash: The commit hash.

    Returns:
        The commit date.
    """

    query = "select committer_date from commits \
             where hash like'"+str(hash)+"'"
    cur.execute(query)
    res = cur.fetchone()
    if res is not None:
        return res[0]
    else:
        return None


def get_first_commit_date(cur, start_date, end_date):
    """
    Gets the date of the first commit in the given range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The first commit date.
    """



def get_commits(cur, start_date, end_date):
    """
    Gets the commits authored by all developers in the given
    revision range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of all authored commits.
    """
    query = "select hash from commits \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<='"+str(end_date)+str("'")
    cur.execute(query)
    res = cur.fetchall()

    commits = []
    for r in res:
        commits.append(str(r[0]))
    return commits


def get_commits_info(cur, start_date, end_date):
    """
    Gets the commits authored by all developers in the given
    revision range, annotated with date and author.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        List of all authored commits with author and date.
    """
    query = "select hash, author_id, committer_date from commits \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<'"+str(end_date)+str("'")

    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["hash", "author", "time"])
    return df


def get_edits_info(cur, start_date, end_date):
    """
    Gets the file edits authored by all developers in the given
    revision range, annotated with date, author and modified lines.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        Annotated list of all authored file edits.
    """
    query = "select * from (select author_id, hash, committer_date \
                            from commits) c \
             join (select commit_hash, new_path, total_added_lines, total_removed_lines \
                   from edits) e on e.commit_hash = c.hash \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<'"+str(end_date)+str("'")
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["developer", "hash", "committer_date", "commit_hash", "file", "added", "removed"])
    return df[["developer", "hash", "committer_date", "file", "added", "removed"]]


def get_num_files(cur, start_date, end_date):
    """
    Gets the number of distinct files changed in the given
    revision range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The number of distinct changed files.
    """

    query = "select distinct new_path \
             from edits e join commits c on e.commit_hash = c.hash \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<='"+str(end_date)+str("'")+ " \
             union \
             select distinct old_path \
             from edits e join commits c on e.commit_hash = c.hash \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<='"+str(end_date)+str("'")

    cur.execute(query)
    res = cur.fetchall()
    num_files = len(res)
    return num_files


def get_dev_commits(cur, start_date, end_date, dev):
    """
    Gets the number of commits authored by the given developer
    in the given revision range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        dev: The author ID.

    Returns:
        The number of authored commits.
    """
    query = "select count(hash) from commits \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<='"+str(end_date)+str("'")+ " and \
                   author_id="+str(dev)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_dev_diff_size(cur, start_date, end_date, dev):
    """
    Gets the number of lines (added and removed) authored by a
    developer in a given revision range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        dev: The author ID.

    Returns:
        The number of authored lines.
    """
    query = "select sum(total_added_lines)+sum(total_removed_lines) \
             from (select distinct * \
                   from (select hash, filename, author_id, \
                                total_removed_lines, total_added_lines,\
                                committer_date\
                         from commits c join edits e on c.hash=e.commit_hash \
                         where committer_date>='"+str(start_date)+"' and \
                               committer_date<='"+str(end_date)+"' and author_id="+str(dev)+") t) t2"
    cur.execute(query)
    res = cur.fetchone()

    if not res[0] is None:
        return res[0]
    else:
        return 0


def get_num_entities(cur, start_date, end_date):
    """
    Gets the number of entity changes in the given
    revision range.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.

    Returns:
        The number of entity changes.
    """

    query = "select * \
             from (select * \
                   from edits \
                   where (edit_type like 'replacement' or edit_type like 'addition' or edit_type like 'deletion')) e join \
                   commits c on e.commit_hash = c.hash \
             where committer_date>='"+str(start_date)+"' and \
                   committer_date<'"+str(end_date)+str("'")

    cur.execute(query)
    res = cur.fetchall()
    num_files = len(res)
    return num_files
