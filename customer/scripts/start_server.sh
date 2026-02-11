#!/bin/bash
cd /home/ec2-user/customer
# Use PM2 to stop any existing instance and start the new one
pm2 stop customer-service || true
pm2 start index.js --name "customer-service"