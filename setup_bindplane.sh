#!/bin/bash
set -euxo pipefail
exec > >(tee /var/log/bindplane-install.log) 2>&1

DB_USER=${DB_USER:-bindplane_user}
DB_PASS=${DB_PASS:-StrongPassword@2025}
BP_ADMIN_USER=${BP_ADMIN_USER:-admin}
BP_ADMIN_PASS=${BP_ADMIN_PASS:-test}

echo "=== Installing PostgreSQL ==="
apt update
apt install -y postgresql postgresql-contrib curl

systemctl enable postgresql
systemctl start postgresql

echo "=== Creating database and user ==="
sudo -i -u postgres psql <<EOF
CREATE DATABASE bindplane;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE bindplane TO $DB_USER;
\c bindplane
GRANT USAGE, CREATE ON SCHEMA public TO $DB_USER;
ALTER SCHEMA public OWNER TO $DB_USER;
\q
EOF

echo "=== Installing BindPlane ==="
curl -fsSL https://storage.googleapis.com/bindplane-op-releases/bindplane/latest/install-linux.sh -o install.sh
bash install.sh --version 1.96.7 --init --accept-license --no-prompt \
  --admin-user $BP_ADMIN_USER --admin-password $BP_ADMIN_PASS
rm install.sh

systemctl enable bindplane
systemctl start bindplane

echo "=== Installing BindPlane Agent ==="
curl -fsSL https://packages.bindplane.com/agent/install.sh | bash
systemctl start bindplane-agent

echo "=== INSTALLATION COMPLETED SUCCESSFULLY ==="
