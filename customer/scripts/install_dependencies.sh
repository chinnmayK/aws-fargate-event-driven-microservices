#!/bin/bash

# 1. Ensure we are in the correct directory
cd /home/ubuntu/customer

# 2. Fix permissions (Just in case the zip lost them)
# This makes sure the ubuntu user owns everything in the folder
sudo chown -R ubuntu:ubuntu /home/ubuntu/customer

# 3. Install dependencies
# Using --yes to prevent any interactive prompts that hang the script
npm install --yes

# 4. Check for PM2 and install if missing
if ! command -v pm2 &> /dev/null
then
    echo "PM2 not found, installing..."
    sudo npm install -g pm2
fi