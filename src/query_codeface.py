# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Helper functions to query data from the Codeface database.

import pandas as pd


def get_project_id(cur, project):
    """
    Gets the project IDs for a given project name.

    Args:
        cur: The MySQL database connection cursor.
        project: Project name in Codeface database.

    Returns:
        The project ID.
    """
    query = "select id from project where name like '"+project+"'"
    cur.execute(query)
    pid = cur.fetchone()[0]
    return pid


def get_range_ids(cur, pid):
    """
    Gets all range IDs for a given project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.

    Returns:
        The list of all revision ranges.
    """
    query = "select releaseRangeID \
            from revisions_view \
            where projectId="+str(pid)
    cur.execute(query)
    res = cur.fetchall()
    range_ids = [r[0] for r in res]
    return range_ids


def get_devs(cur, pid, range_id):
    """
    Gets all active developers (authors) in a specific revision range of a project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        List of active developers (author IDs).
    """

    query = "select distinct(p.id) \
             from person p inner join commit c on p.id=c.author \
             where c.releaseRangeId="+str(range_id)+" and c.projectId="+str(pid)
    cur.execute(query)
    res = cur.fetchall()

    devs = []
    for r in res:
        devs.append(str(r[0]))
    return devs


def get_devs_activity(cur, pid, range_id):
    """
    Gets all active developers (authors) with their number of authored commits
    in a specific revision range of a project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with active developers (authors) and their number of commits.
    """
    query = "select personId, any_value(name) as name, \
             any_value(email1) as email1, any_value(email2) as email2, \
             any_value(email3) as email3, any_value(email4) as email4, \
             any_value(email5) as email5, count(distinct dev.commitId) as n_commits \
             from (select p.id as personId, name, email1, email2, email3, \
                   email4, email5, c.id as commitId \
                   from person p inner join commit c on p.id=c.author \
                   where c.releaseRangeId="+str(range_id)+" and \
                   c.projectId="+str(pid)+") as dev\
             group by personId"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["personId", "name", "email1", "email2",
                                    "email3", "email4", "email5", "n_commits"])
    return df


def get_num_devs(cur, pid, range_id):
    """
    Gets the number of active developers (authors and committers) in a specific
    revision range of a project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of active developers in the respective range.
    """
    query = "select count(*) \
             from (select distinct author \
                   from commit c \
                   inner join revisions_view r on c.releaseRangeId=r.releaseRangeId \
                   where c.projectId="+str(pid)+" and \
                   c.releaseRangeId="+str(range_id)+"\
                   union \
                   select distinct committer \
                   from commit c \
                   where c.projectId="+str(pid)+" and \
                   c.releaseRangeId="+str(range_id)+") as person"
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_dev_name(cur, person_id):
    query = "select name, email1, email2, email3, email4, email5 \
             from person \
             where id="+str(person_id)
    cur.execute(query)
    res = cur.fetchall()

    df = pd.DataFrame(res, columns=["name", "email1", "email2", "email3",
                                    "email4", "email5"])
    name = df["name"][0]
    if df["email1"][0]:
        name += " <"+df["email1"][0]
    if df["email2"][0]:
        name += "> | <"+df["email2"][0]
    if df["email3"][0]:
        name += "> | <"+df["email3"][0]
    if df["email4"][0]:
        name += "> | <"+df["email3"][0]
    name += ">"
    return name


def get_diff_size(cur, pid, range_id):
    """
    Gets the number of changed lines (added and removed)
    changed by all developers in a given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of changed lines.
    """
    query = "select sum(DiffSize) \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId<="+str(range_id)
    cur.execute(query)
    res = cur.fetchone()

    if not res[0] is None:
        return res[0]
    else:
        return 0


def get_dev_diff_size_project(cur, pid, range_id, m):
    """
    Gets the total number of lines (added and removed) changed by a
    developer in the entire project up to the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of changed lines.
    """
    query = "select sum(DiffSize) \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId<="+str(range_id)+" and \
             author="+str(m)
    cur.execute(query)
    res = cur.fetchone()

    if not res[0] is None:
        return res[0]
    else:
        return 0


def get_dev_diff_size(cur, pid, range_id, m):
    """
    Gets the number of lines (added and removed) changed by a
    developer in a given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of changed lines.
    """
    query = "select sum(DiffSize) \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId="+str(range_id)+" and \
             author="+str(m)
    cur.execute(query)
    res = cur.fetchone()

    if not res[0] is None:
        return res[0]
    else:
        return 0


def get_dev_commits(cur, pid, range_id, m):
    """
    Gets the number of commits authored by the given developer in the given
    revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: The revision range ID.
        m: The developer ID.

    Returns:
        The number of authored commits.
    """
    query = "select count(*) from commit \
             where releaseRangeId="+str(range_id)+" \
             and author="+str(m)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_dev_commits_project(cur, pid, range_id, m):
    query = "select count(*) \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId<="+str(range_id)+" and \
             author="+str(m)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_commits(cur, pid, range_id):
    """
    Gets all commits in the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The list of commits.
    """
    query = "select * \
             from commit \
             where projectId="+str(pid)+" and \
             releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchall()

    # Extract commit hashes.
    commits = [c[1] for c in res]
    return commits


def get_commit_hashes(cur, pid, range_id):
    """
    Gets the list of all commit hashes for the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The list of commit hashes
    """
    query = ("select name as project, commitHash \
             from commit c inner join project p \
             on c.projectId=p.id \
             where p.id="+str(pid)+" and c.releaseRangeId="+str(range_id))
    cur.execute(query)
    res = cur.fetchall()

    hashes = [r for r in res]
    return hashes


def get_commits_info(cur, start_date, end_date, pid):
    """
    Gets the commits authored by all developers in the given
    revision range, annotated with date and author.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        pid: Project ID in Codeface database.

    Returns:
        List of all authored commits with author and date.
    """
    query = "select commitHash, author, commitDate from commit \
             where commitDate>='"+str(start_date)+"' and \
                   commitDate<'"+str(end_date)+"' and \
                   projectId="+str(pid)

    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["hash", "author", "time"])
    return df


def get_commit_date(cur, hash, pid):
    """
    Gets the date at which the given commit was committed to the
    repository.

    Args:
        cur: The SQLite database connection cursor.
        hash: The commit hash.
        pid: Project ID in Codeface database.

    Returns:
        The commit date.
    """

    query = "select commitDate from commit \
             where commitHash like'"+str(hash)+"' and \
                   projectId="+str(pid)
    cur.execute(query)
    res = cur.fetchone()
    if res is not None:
        return res[0]
    else:
        return None


def get_num_files(cur, pid, range_id):
    """
    Gets the number of changed files in the given revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The number of changed files.
    """
    query = "select count(distinct file) \
             from commit_dependency d \
             inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" and \
             c.releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchone()
    return res[0]


def get_files_activity(cur, pid, range_id):
    """
    Gets the names of all changed files with their number of changing commits
    in the given revision range of the project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with files and their number of commits.
    """
    query = "select file, count(distinct commitId) as n_commits \
             from commit_dependency d inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" \
             and c.releaseRangeId="+str(range_id)+" \
             group by file order by n_commits desc"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["file", "n_commits"])
    return df


def get_files_info(cur, start_date, end_date, pid):
    """
    Gets the file edits authored by all developers in the given
    revision range, annotated with date, author and modified lines.

    Args:
        cur: The SQLite database connection cursor.
        start_date: Start date of the revision range.
        end_date: End date of the revision range.
        pid: Project ID in Codeface database.

    Returns:
        Annotated list of all authored file edits.
    """

    query = "select author, commitHash, commitDate, file, size  \
             from commit c join commit_dependency d on c.id=d.commitId \
             where commitDate>='"+str(start_date)+"' and \
                   commitDate<'"+str(end_date)+"' and \
                   projectId="+str(pid)

    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["developer", "hash", "date", "file", "churn"])
    return df


def get_entities(cur, pid, range_id):
    """
    Gets the unique names of changed entities (functions) in the given
    revision range.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        The changed entities.
    """
    query = "select entityId \
             from (select id, projectId, releaseRangeId from commit) as c \
             inner join commit_dependency d on c.id=d.commitId \
             where c.projectId="+str(pid)+" and \
             c.releaseRangeId="+str(range_id)
    cur.execute(query)
    res = cur.fetchall()

    if res is not None:
        return [str(r[0]) for r in res]
    else:
        return None


def get_entities_activity(cur, pid, range_id):
    """
    Gets the names of all changed entities with their number of changing
    commits in the given revision range of the project.

    Args:
        cur: The MySQL database connection cursor.
        pid: Project ID in Codeface database.
        range_id: Revision range ID.

    Returns:
        Data frame with entities and their number of commits.
    """
    query = "select entityId, count(distinct commitId) as n_commits \
             from commit_dependency d inner join commit c on d.commitId=c.id \
             where c.projectId="+str(pid)+" \
             and c.releaseRangeId="+str(range_id)+" group by entityId \
             order by n_commits desc"
    cur.execute(query)
    res = cur.fetchall()
    df = pd.DataFrame(res, columns=["entity", "n_commits"])
    return df
