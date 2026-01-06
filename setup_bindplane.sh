#!/bin/bash
set -euxo pipefail

# ------------------------------
# Variables passed from Terraform templatefile
# ------------------------------
DB_USER="${db_user}"
DB_PASS="${db_pass}"
BP_ADMIN_USER="${bp_admin_user}"
BP_ADMIN_PASS="${bp_admin_pass}"

# ------------------------------
# Update OS and install prerequisites
# ------------------------------
echo "===== UPDATING SYSTEM ====="
apt-get update -y
apt-get install -y postgresql postgresql-contrib curl jq

# ------------------------------
# Start and enable PostgreSQL
# ------------------------------
echo "===== STARTING POSTGRESQL ====="
systemctl enable postgresql
systemctl start postgresql

# ------------------------------
# Create Postgres user & database (idempotent)
# ------------------------------
echo "===== CONFIGURING DATABASE ====="
sudo -u postgres psql <<EOF
DO \$\$ BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE ROLE $DB_USER LOGIN PASSWORD '$DB_PASS';
   END IF;
END \$\$;

DO \$\$ BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
      CREATE DATABASE bindplane OWNER $DB_USER;
   END IF;
END \$\$;
EOF

# ------------------------------
# Install BindPlane Server using official install script
# ------------------------------
echo "===== INSTALLING BINDPLANE SERVER ====="
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install-linux.sh
bash install-linux.sh --version 1.96.7 --init --accept-license --no-prompt \
    --admin-user "$BP_ADMIN_USER" --admin-password "$BP_ADMIN_PASS"
rm install-linux.sh

# Enable and start BindPlane services
systemctl enable bindplane-server
systemctl restart bindplane-server
systemctl enable bindplane-agent
systemctl restart bindplane-agent

# ------------------------------
# Confirm installation
# ------------------------------
echo "===== BINDPLANE INSTALL COMPLETE ====="
