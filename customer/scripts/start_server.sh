#!/bin/bash
cd /home/ubuntu/customer

# Stop the existing process if it's running
pm2 delete customer-service || true

# Start the application using the injected .env file
# We force NODE_ENV=prod to match your config/index.js logic
NODE_ENV=prod pm2 start index.js --name "customer-service"

# Save the PM2 list so it restarts on reboot
pm2 save