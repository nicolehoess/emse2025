#! /bin/bash

# Start MySQL service
sudo service mysql start

# Start ID service accessing the database
cd /home/emse/tools/codeface/snapshot/id_service
bash start_id_service.sh&

# Prepare for user interaction
mysql -u codeface -pcodeface codeface < /home/emse/tools/codeface/snapshot/docker/config.sql
/bin/bash
