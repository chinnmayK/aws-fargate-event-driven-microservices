#!/bin/bash
cd /home/ubuntu/customer

# Install node modules if they aren't fully copied or need rebuilding
npm install

# Ensure PM2 is installed globally
if ! command -v pm2 &> /dev/null
then
    sudo npm install -g pm2
fi