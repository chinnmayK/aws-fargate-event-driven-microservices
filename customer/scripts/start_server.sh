#!/bin/bash
# Move to the app directory
cd /home/ubuntu/customer

# Delete any existing process to avoid name conflicts
pm2 delete "customer-service" || true

# Start the app using the correct path to index.js
pm2 start src/index.js --name "customer-service"

# Save the process list so it persists on reboots
pm2 save