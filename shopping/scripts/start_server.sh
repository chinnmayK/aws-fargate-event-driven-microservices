#!/bin/bash
cd /home/ec2-user/shopping
# Use PM2 to stop any existing instance and start the new one
pm2 stop shopping-service || true
pm2 start index.js --name "shopping-service"