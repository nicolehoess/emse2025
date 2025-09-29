#!/bin/bash

# Replace US by local Ubuntu repository to avoid downtimes
sudo sed -i 's/us.archive.ubuntu.com/de.archive.ubuntu.com/' /etc/apt/sources.list

sudo apt update -qq
sudo apt install --no-install-recommends software-properties-common dirmngr

echo "Adding R cran repositories"
#version=`lsb_release -r | awk '{ print $2;}'`

#case ${version} in
    #"14.04")
	#echo "deb http://cran.rstudio.com/bin/linux/ubuntu trusty/" | sudo tee -a /etc/apt/sources.list
	#;;
    #"16.04")
	#echo "deb http://cran.rstudio.com/bin/linux/ubuntu xenial/" | sudo tee -a /etc/apt/sources.list
	#;;
    #*) echo "Unsupported version of Ubuntu detected, aborting"
    #   exit 1;;
#esac

#gpg --keyserver keyserver.ubuntu.com --recv-key E084DAB9
#gpg -a --export E084DAB9 | sudo apt-key add -

wget -qO- https://cloud.r-project.org/bin/linux/ubuntu/marutter_pubkey.asc | sudo tee -a /etc/apt/trusted.gpg.d/cran_ubuntu_key.asc

sudo add-apt-repository "deb https://cloud.r-project.org/bin/linux/ubuntu $(lsb_release -cs)-cran40/"

#echo "Adding node.js repository"
#sudo add-apt-repository -y ppa:chris-lea/node.js

sudo apt-get update -qq
