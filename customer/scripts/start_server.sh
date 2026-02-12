#!/bin/bash
# Ensure path is set for the ubuntu user
export PATH=$PATH:/usr/bin:/usr/local/bin

cd /home/ubuntu/customer

# Stop the existing process to avoid port conflicts
pm2 delete customer-service || true

# Start the application pointing to the src/index.js entry point
# We use --update-env to ensure it reads the new .env file created by CodeBuild
NODE_ENV=prod pm2 start src/index.js --name "customer-service" --update-env

# Save the PM2 list to ensure persistence on reboot
pm2 save