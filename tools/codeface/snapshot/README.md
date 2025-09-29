# Codeface

## Overview

Codeface is a framework for analysing the technical and social evolution of
software projects.

Motivated to analyse software development processes in large-scale software
projects, Codeface mines data from version control systems (VCS), developer
communication channels and static dependencies to gain insights into
developer collaboration and communication as well as software quality.

You can read more about Codeface's motivation on its
[website](http://siemens.github.io/codeface).

## Installation

We recommend to set up Codeface with Docker.

### Install Codeface with Docker

If Docker is not yet installed on your system, please consult its
[installation instructions](https://docs.docker.com/engine/install/).

1. Clone this repository

2. Build the Docker image from the Dockerfile in your local repository (this
may take up to an hour)

    ```
    docker build -t codeface .
    ```

3. Run a Docker container from your `codeface` image

    ```
    docker run --name codeface -d -t --user codeface codeface
    ```

    Optionally, you can export the MySQL database port (3306) to your host
    system or share data and source code between your host system and the
    container. Please consult the `docker run`
    [documentation](https://docs.docker.com/engine/reference/run/) for details.

### Getting started

1. Log in to your Docker container

    ```
    docker exec -it codeface bash
    ```

2. Run an example analysis of the QEMU processor emulator (this may take
several hours).

    ```
    cd /home/codeface/codeface && ./analysis_example.sh
    ```

3. Verify the results in the local `codeface` database (user and password
`codeface`) and in the result directory (`/home/codeface/res`).

## Custom software analyses

Codeface supports several analysis modes which can be used for your custom
analyses. Each analysis mode is reflected by a command in Codeface's CLI.

### Standard analysis

The standard analysis bundles a set of analyses which can be run on each git
repository.

Codeface analyses software evolution in time windows. It parses commits from
the repository and stores them in a local database. Codeface constructs the
developer collaboration network on the fly. Based on the results, it detects
communities, summarises structural project trends and estimates development
efforts over time.

#### Analysis steps

1. Provide the Git repository of the software project of choice, for example
using `git clone`.

2. Create a project configuration file in the `conf` folder. The existing
configuration files may serve as a reference.

3. Run the standard analysis using the `codeface run` command.

    A `codeface run` command takes the following form:

    ```
    codeface run [OPTIONS] -c [TOOL CONF] -p [PROJECT CONF] [RESULT DIR] [GIT DIR]
    ```

    | Option                 | Description                                        |
    | ---------------------- | -------------------------------------------------- |
    | `-c`, `--config`       | Codeface configuration file (codeface.conf) |
    | `-p`, `--project`      | Project configuration file |
    | `-l`, `--loglevel`     | Log level. Can be one of `debug`, `devinfo`, `info`, `warning`, `error`. |
    | `-f`, `--logfile`      | Optional log file. |
    | `-j`, `--jobs`         | Number of cores to use in parallel. Default is `1`. |
    | `--recreate`           | Force a delete of the project in the database. |
    | `--reuse-vcs-analysis` | Re-use an existing vcs-analysis.db from a previous analysis run. |
    | `--no-export`          | Skip LaTeX report generation and dot compilation (local artificats). |

4. Inspect the results in the local `codeface` database (user and password
`codeface`) and in the given result directory.

### Mailing list analysis

In large distributed open source software projects, mailing lists are an
established means of communication.

This analysis mode parses mails from an existing mail box, analyses frequent
subjects and constructs the communication network.

#### Analysis steps

1. Run all standard analyses for the project of choice as described above.

2. Download the mailing list for the project and export it to an
`.mbox` file.

3. Run the mailing list analysis using the `codeface ml` command.

    A `codeface ml` command takes the following form:

    ```
    codeface ml [OPTIONS] -c [TOOL CONF] -p [PROJECT CONF] [RESULT DIR] [MAIL DIR]
    ```

    | Option                 | Description                                        |
    | ---------------------- | -------------------------------------------------- |
    | `-c`, `--config`       | Codeface configuration file (codeface.conf) |
    | `-p`, `--project`      | Project configuration file |
    | `-l`, `--loglevel`     | Log level. Can be one of `debug`, `devinfo`, `info`, `warning`, `error`. |
    | `-f`, `--logfile`      | Optional log file. |
    | `-j`, `--jobs`         | Number of cores to use in parallel. Default is `1`. |
    | `--use-corpus`         | Re-use an existing corpus file from a previous analysis run. |

4. Inspect the results in the local `codeface` database (user and password
`codeface`) and in the given result directory.