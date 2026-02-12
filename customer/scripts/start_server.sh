#!/bin/bash
cd /home/ubuntu/customer
pm2 delete "customer-service" || true

# Force NODE_ENV=prod so the config logic finds the .env file
NODE_ENV=prod pm2 start src/index.js --name "customer-service"
pm2 save