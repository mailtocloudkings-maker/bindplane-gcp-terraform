#!/bin/bash
set -xe

# Receive variables from Terraform
DB_USER=${DB_USER}
DB_PASS=${DB_PASS}
BP_ADMIN_USER=${BP_ADMIN_USER}
BP_ADMIN_PASS=${BP_ADMIN_PASS}

echo "Starting VM setup..."
echo "PostgreSQL user: $DB_USER"
echo "BindPlane admin: $BP_ADMIN_USER"

# Update system packages
echo "Updating system packages..."
sudo apt update -y
sudo apt upgrade -y

# Install PostgreSQL
echo "Installing PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib curl

# Start and enable PostgreSQL
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Configure PostgreSQL
echo "Creating database and user..."
sudo -i -u postgres psql <<EOF
CREATE DATABASE bindplane;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE bindplane TO $DB_USER;
\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO $DB_USER;
ALTER SCHEMA public OWNER TO $DB_USER;
EOF

echo "PostgreSQL setup completed!"

# Install BindPlane Server
echo "Installing BindPlane Server..."
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --version 1.96.7 --init --no-prompt --admin-user "$BP_ADMIN_USER" --admin-password "$BP_ADMIN_PASS"
rm install-linux.sh

sudo systemctl enable bindplane
sudo systemctl start bindplane

echo "BindPlane Server installed and running!"

# Install BindPlane Agent
echo "Installing BindPlane Agent..."
curl -fsSL https://packages.bindplane.com/agent/install.sh | sudo bash
sudo systemctl start bindplane-agent

echo "BindPlane Agent installed and running!"
echo "VM setup completed successfully!"
