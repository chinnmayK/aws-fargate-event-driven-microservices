#!/bin/bash
set -e
# 1. Move to app directory
cd /home/ubuntu/products

# 2. FIX PERMISSIONS: Ensure the 'ubuntu' user owns the folder
# This solves the EACCES permission denied error
sudo chown -R ubuntu:ubuntu /home/ubuntu/products

# 3. Update apt and install Node.js if missing
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs build-essential
fi

# 4. Install PM2 globally
sudo npm install pm2 -g

# 5. Install local app dependencies as the 'ubuntu' user
npm install