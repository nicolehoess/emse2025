#!/bin/bash
# Copyright Roger Meier <roger@bufferoverflow.ch>
# SPDX-License-Identifier:	Apache-2.0 BSD-2-Clause GPL-2.0+ MIT WTFPL

echo "Providing R libraries"

sudo DEBIAN_FRONTEND=noninteractive apt-get -qqy install r-base r-base-dev
# sudo DEBIAN_FRONTEND=noninteractive apt -qqy install r-base r-base-dev

sudo R CMD javareconf

sudo DEBIAN_FRONTEND=noninteractive apt-get -qqy install \
	r-cran-zoo r-cran-xts \
	r-cran-xtable r-cran-reshape r-cran-stringr r-cran-scales \
	r-cran-scales r-cran-rmysql r-cran-rcurl r-cran-mgcv \
	r-cran-rjson r-cran-testthat libx11-dev libssl-dev libssh2-1-dev \
	libudunits2-dev

# install newer version of GDAL for compatibility with automatically selected packages
#sudo add-apt-repository -y ppa:ubuntugis/ppa
#sudo apt-get update -qq
#sudo DEBIAN_FRONTEND=noninteractive apt-get -y install libgdal-dev libgdal20

echo "Providing R libraries - packages.r"

sudo Rscript packages.r
