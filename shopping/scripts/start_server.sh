#!/bin/bash
cd /home/ubuntu/shopping
# Start/Restart app with PM2
pm2 delete "shopping-service" || true
pm2 start index.js --name "shopping-service"
# Optional: Ensure PM2 starts on boot
pm2 save