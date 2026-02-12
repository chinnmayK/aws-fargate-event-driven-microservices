#!/bin/bash
cd /home/ubuntu/customer
# Start/Restart app with PM2
pm2 delete "customer-service" || true
pm2 start index.js --name "customer-service"
# Optional: Ensure PM2 starts on boot
pm2 save