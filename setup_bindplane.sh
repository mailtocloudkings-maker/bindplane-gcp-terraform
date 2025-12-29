#!/bin/bash
set -euxo pipefail

# Use environment variables passed from Terraform
DB_USER=${DB_USER:-bindplane_user}
DB_PASS=${DB_PASS:-StrongPassword@2025}
BP_ADMIN_USER=${BP_ADMIN_USER:-admin}
BP_ADMIN_PASS=${BP_ADMIN_PASS:-test}

LOGFILE="/tmp/bindplane_setup.log"
exec > >(tee -a "$LOGFILE") 2>&1

echo "=== Updating system packages ==="
sudo apt update && sudo apt upgrade -y

echo "=== Installing PostgreSQL 14 and curl ==="
sudo apt install -y postgresql-14 postgresql-client-14 curl

echo "=== Starting PostgreSQL ==="
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "=== Creating PostgreSQL database and user ==="
sudo -i -u postgres psql <<EOF
CREATE DATABASE bindplane;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE bindplane TO $DB_USER;
\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO $DB_USER;
ALTER SCHEMA public OWNER TO $DB_USER;
\q
EOF

echo "=== Installing BindPlane Server ==="
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --version 1.96.7 --init --admin-user "$BP_ADMIN_USER" --admin-password "$BP_ADMIN_PASS"
rm install-linux.sh
sudo systemctl enable bindplane
sudo systemctl start bindplane

echo "=== Installing BindPlane Agent ==="
curl -fsSL https://packages.bindplane.com/agent/install.sh | sudo bash
sudo systemctl start bindplane-agent

echo "=== VM setup completed successfully! ==="
