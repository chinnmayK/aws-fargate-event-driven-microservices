#!/bin/bash
# Move to the app directory
cd /home/ec2-user/customer
# Check if Node is installed, if not, install it
if ! command -v node &> /dev/null; then
    curl -sL https://rpm.nodesource.com/setup_18.x | sudo bash -
    sudo yum install -y nodejs
fi
# Install PM2 globally to keep the app running in the background
sudo npm install pm2 -g
# Install local dependencies
npm install