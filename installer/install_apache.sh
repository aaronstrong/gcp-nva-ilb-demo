#!/bin/bash
# Exit immediately if any command fails
set -e

# Update package lists
apt-get update

# Install Apache2 without user interaction
apt-get install -y apache2

# Ensure Apache starts on boot and is running
systemctl enable apache2
systemctl start apache2

# Optional: Create a custom landing page
echo '<!doctype html><html><body><h1>Welcome to my GCP Debian 11 Server via Terraform!</h1></body></html>' > /var/www/html/index.html
