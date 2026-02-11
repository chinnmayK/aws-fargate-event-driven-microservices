#!/bin/bash
cd /home/ec2-user/products
# Use PM2 to stop any existing instance and start the new one
pm2 stop products-service || true
pm2 start index.js --name "products-service"