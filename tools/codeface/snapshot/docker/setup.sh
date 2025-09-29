#! /bin/bash

# Install Anaconda
cd /home/emse
curl -O https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh
bash Anaconda3-2024.10-1-Linux-x86_64.sh -b -p /home/emse/anaconda3
rm Anaconda3-2024*
eval "$(/home/emse/anaconda3/bin/conda shell.bash hook)"
conda init
echo ". /home/emse/anaconda3/etc/profile.d/conda.sh" >> /home/emse/.bashrc
source /home/emse/.bashrc
conda config --set auto_activate_base False

# Make sure to execute scripts from the intended path
cd /home/emse/tools/codeface/snapshot

# Install required dependencies
integration-scripts/install_repositories.sh
integration-scripts/install_common.sh
integration-scripts/install_codeface_R.sh
integration-scripts/install_codeface_node.sh
integration-scripts/install_codeface_python.sh
integration-scripts/install_cppstats.sh

# Start the MySQL service
sudo service mysql start

# Allow database connections via the MySQL socket
# for all users
chmod 755 /var/run/mysqld

# Set up Codeface and Codeface test databases
integration-scripts/setup_database.sh
