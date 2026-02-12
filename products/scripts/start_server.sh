#!/bin/bash
cd /home/ubuntu/products
# Start/Restart app with PM2
pm2 delete "products-service" || true
pm2 start index.js --name "products-service"
# Optional: Ensure PM2 starts on boot
pm2 save