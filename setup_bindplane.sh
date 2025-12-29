#!/bin/bash
set -euxo pipefail

echo "===== INSTALL START: $(date) ====="

DB_USER=${DB_USER:-bindplane_user}
DB_PASS=${DB_PASS:-StrongPassword@2025}
BP_ADMIN_USER=${BP_ADMIN_USER:-admin}
BP_ADMIN_PASS=${BP_ADMIN_PASS:-test}

echo "Updating OS..."
apt update -y

echo "Installing PostgreSQL..."
apt install -y postgresql postgresql-contrib curl

systemctl enable postgresql
systemctl start postgresql

echo "Creating database and user..."
sudo -i -u postgres psql <<EOF
DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'bindplane') THEN
      CREATE DATABASE bindplane;
   END IF;
END\$\$;

DO \$\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
   END IF;
END\$\$;

GRANT ALL PRIVILEGES ON DATABASE bindplane TO $DB_USER;
\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO $DB_USER;
ALTER SCHEMA public OWNER TO $DB_USER;
\q
EOF

echo "Installing BindPlane Server..."
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install.sh
bash install.sh --version 1.96.7 --init --accept-license --no-prompt \
 --admin-user $BP_ADMIN_USER --admin-password $BP_ADMIN_PASS
rm install.sh

systemctl enable bindplane
systemctl start bindplane

echo "Installing BindPlane Agent..."
curl -fsSL https://packages.bindplane.com/agent/install.sh | bash
systemctl start bindplane-agent

echo "===== INSTALL COMPLETE SUCCESSFULLY ====="
