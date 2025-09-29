# SPDX-FileCopyrightText: 2025 OTH Regensburg, Nicole Hoess <nicole.hoess@othr.de>
# SPDX-License-Identifier: GPL-2.0-only

# Base image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update base system packages
RUN apt-get update && apt-get -y install --no-install-recommends \
        software-properties-common build-essential gcc gfortran g++ \
        curl htop sudo tmux wget vim git python3-dev python3-pip r-base \
        libfontconfig1-dev libssl-dev libxml2-dev r-base-dev \
        libcurl4-openssl-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
        libopenmpi-dev libpq-dev libblas-dev liblapack-dev \
        libatlas-base-dev texlive-full cloc ca-certificates \
        libwebp-dev pkg-config cmake libcairo2 libcairo2-dev \
        libmysqlclient-dev libgdal-dev gdal-bin sqlite3 libmagick++-dev

# Add user
RUN groupadd emse && useradd -ms /bin/bash -d /home/emse -g emse emse
RUN sudo usermod -aG sudo emse
RUN bash -c "sudo echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Add directories for comparative analysis
COPY ./analysis /home/emse/analysis
COPY ./data /home/emse/data
COPY ./docker /home/emse/docker
COPY ./literature /home/emse/literature
COPY ./original_studies /home/emse/original_studies
COPY ./plot /home/emse/plot
COPY ./results /home/emse/results
COPY ./src /home/emse/src
COPY ./tools /home/emse/tools

# Change permissions for the emse user
RUN sudo chown -R emse:emse /home/emse
RUN sudo chmod -R 755 /home/emse

# Run the remaining setup as user
USER emse

# Install Kaiaulu dependencies
RUN bash /home/emse/tools/kaiaulu/snapshot/setup/dependencies.sh

# Install analysis dependencies, including those for other tools
RUN bash /home/emse/analysis/setup.sh

# Start up
WORKDIR /home/emse
ENTRYPOINT ["/home/emse/docker/entrypoint.sh"]
