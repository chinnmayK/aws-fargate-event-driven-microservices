#!/bin/bash
set -e
cd /home/ubuntu/products

# Update apt and install Node.js if missing
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs build-essential
fi

# Install PM2 globally
sudo npm install pm2 -g

# Install local app dependencies
npm install