#!/bin/bash
set -aex

# Kill existing processes
pkill -9 vault || true
sleep 5s

# Start the vault server
vault server -dev -dev-root-token-id root -log-level=trace -dev-plugin-dir=plugin-dir > /tmp/server.log 2>&1 &

# Enable the approle auth method, configure a role and generate a secret ID
vault auth enable approle
vault write auth/approle/role/role1 bind_secret_id=true token_policies=demopolicy token_ttl=3s token_max_ttl=10s
secretID=$(vault write -format json -f auth/approle/role/role1/secret-id | jq -r '.data.secret_id')
roleID=$(vault read -format json auth/approle/role/role1/role-id | jq -r '.data.role_id')

# Save the secret ID and the role ID in files that are picked up by the agent
echo -n $secretID > /tmp/secretIDFile
echo -n $roleID > /tmp/roleIDFile

cd dev

cat > config/agent.hcl -<<EOF
auto_auth {
    method {
        type = "approle"
        config = {
            role_id_file_path = "/tmp/roleIDFile"
            secret_id_file_path = "/tmp/secretIDFile"
        }
    }

    sink {
        type = "file"
        config = {
            path = "/tmp/approle-token"
        }
    }
}

vault {
  address = "http://127.0.0.1:8200"
}
EOF

# Start the agent
vault agent -config config/agent.hcl > /tmp/agent.log 2>&1 &
