#!/bin/bash
# Force the path to include standard bin locations
export PATH=$PATH:/usr/bin:/usr/local/bin

cd /home/ubuntu/customer

# 1. Download the RDS/DocDB SSL bundle (Crucial for Mongoose Connection)
echo "Downloading DocumentDB SSL Bundle..."
wget -O global-bundle.pem https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

# 2. Ensure PM2 is installed and globally linked
if ! command -v pm2 &> /dev/null
then
    echo "PM2 not found. Installing..."
    sudo npm install -g pm2
    # Link the specific binary path we found during debugging
    sudo ln -sf /usr/lib/node_modules/pm2/bin/pm2 /usr/bin/pm2
fi

# 3. Clean install of node_modules
npm install --yes