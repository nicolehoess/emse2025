#!/bin/bash
# Copyright Roger Meier <roger@bufferoverflow.ch>
# SPDX-License-Identifier:	Apache-2.0 BSD-2-Clause GPL-2.0+ MIT WTFPL

echo "Providing id_service"

sudo DEBIAN_FRONTEND=noninteractive apt-get -qqy install npm
cd id_service

# Clear node modules to make sure everything is set up properly
sudo rm -rf node_modules
sudo mkdir node_modules

sudo chown -R emse:emse node_modules
npm set ca null
npm install --no-bin-links
cd ..
