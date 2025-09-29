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

# Add kaiaulu user
RUN groupadd kaiaulu && useradd -ms /bin/bash -d /home/kaiaulu -g kaiaulu kaiaulu
RUN sudo usermod -aG sudo kaiaulu
RUN bash -c "sudo echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"

# Set up kaiaulu package
COPY . /home/kaiaulu/kaiaulu
RUN sudo chown -R kaiaulu:kaiaulu /home/kaiaulu
RUN sudo chmod -R 755 /home/kaiaulu/kaiaulu

# Start up
WORKDIR /home/kaiaulu
ENTRYPOINT /bin/bash
