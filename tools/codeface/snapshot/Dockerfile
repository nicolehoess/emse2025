# Base image
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Update base system packages
RUN apt-get update && apt-get -y install --no-install-recommends \
        software-properties-common build-essential gcc gfortran g++ \
        curl htop sudo tmux wget vim git python3-dev python3-pip r-base \
        libfontconfig1-dev libssl-dev libxml2-dev \
        libcurl4-openssl-dev libharfbuzz-dev libfribidi-dev \
        libfreetype6-dev libpng-dev libtiff5-dev libjpeg-dev \
        libopenmpi-dev libpq-dev libblas-dev liblapack-dev \
        libatlas-base-dev texlive-full

# Add Codeface user
RUN groupadd codeface && useradd -ms /bin/bash -d /home/codeface -g codeface codeface
RUN sudo usermod -aG sudo codeface
RUN bash -c "sudo echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Set up analysis directories
RUN mkdir /home/codeface/git-repos /home/codeface/res

# Set up requirements and install Codeface
COPY . /home/codeface/codeface
RUN bash /home/codeface/codeface/docker/setup.sh
RUN chown -R codeface:codeface /home/codeface
RUN chmod -R 755 /home/codeface/codeface

# Start up
WORKDIR /home/codeface
ENTRYPOINT bash /home/codeface/codeface/docker/entrypoint.sh
