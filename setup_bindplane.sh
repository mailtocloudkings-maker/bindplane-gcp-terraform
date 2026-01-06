#!/bin/bash
set -euxo pipefail

sudo apt-get update -y
sudo apt-get install -y postgresql postgresql-contrib curl jq

sudo systemctl enable postgresql
sudo systemctl start postgresql

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

curl -fsSL https://apt.bindplane.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/bindplane.gpg
echo "deb [signed-by=/usr/share/keyrings/bindplane.gpg] https://apt.bindplane.com stable main" | sudo tee /etc/apt/sources.list.d/bindplane.list

sudo apt-get update -y
sudo apt-get install -y bindplane-server bindplane-agent

sudo tee /etc/bindplane/config.yaml > /dev/null <<EOL
database:
  type: postgres
  postgres:
    host: localhost
    port: 5432
    user: $DB_USER
    password: $DB_PASS
    dbname: bindplane
server:
  listen: 0.0.0.0:3001
EOL

sudo systemctl restart bindplane-server
sudo systemctl start bindplane-agent

sleep 20
curl -X POST http://localhost:3001/api/v1/auth/bootstrap \
 -H "Content-Type: application/json" \
 -d "{\"email\":\"$BP_ADMIN_USER\",\"password\":\"$BP_ADMIN_PASS\"}"
