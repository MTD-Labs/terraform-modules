#!/bin/bash
# Install Docker
# Add Docker's official GPG key:
apt-get update
apt-get -y install ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

# Add the repository to Apt sources:
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Create Loki and Grafana directories
mkdir -p /opt/loki/config
mkdir -p /opt/grafana/provisioning/datasources

# Create Loki config
cat <<'EOF' > /opt/loki/config/loki-local-config.yaml
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  path_prefix: /opt/loki
  storage:
    filesystem:
      chunks_directory: /opt/loki/chunks
      rules_directory: /opt/loki/rules
  replication_factor: 1
  ring:
    instance_addr: 127.0.0.1
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2020-10-24
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: ${alert_manager_url}

compactor:
  working_directory: /opt/loki/compactor
  shared_store: filesystem

# Allow large streams
limits_config:
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_entries_limit_per_query: 5000
  ingestion_rate_mb: 50
  ingestion_burst_size_mb: 100
  per_stream_rate_limit: 50MB
  per_stream_rate_limit_burst: 100MB
EOF

# Create Grafana datasource config
cat <<'EOF' > /opt/grafana/provisioning/datasources/datasource.yaml
apiVersion: 1

datasources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    isDefault: true
    version: 1
    editable: false
EOF

# Create docker-compose.yml
cat <<'EOF' > /opt/docker-compose.yml
version: "3"

networks:
  loki:
    name: loki

services:
  loki:
    image: grafana/loki:3.3.2
    container_name: loki
    restart: always
    ports:
      - "3100:3100"
    command: -config.file=/etc/loki/local-config.yaml
    volumes:
      - /opt/loki/config/loki-local-config.yaml:/etc/loki/local-config.yaml
      - /opt/loki:/opt/loki
    networks:
      - loki

  grafana:
    image: grafana/grafana:11.4.0
    container_name: grafana
    restart: always
    ports:
      - "3000:3000"
    volumes:
      - /opt/grafana/provisioning:/etc/grafana/provisioning
      - grafana-storage:/var/lib/grafana
    environment:
      - GF_SERVER_ROOT_URL=http://${grafana_domain}
      - GF_SERVER_DOMAIN=${grafana_domain}
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=${grafana_admin_password}
      - GF_USERS_ALLOW_SIGN_UP=false
    networks:
      - loki
    depends_on:
      - loki

volumes:
  grafana-storage:
EOF

# Start services
cd /opt
docker compose up -d

# Wait for Loki to be ready
echo "Waiting for Loki to be ready..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -s http://localhost:3100/ready > /dev/null 2>&1; then
    echo "Loki is ready!"
    break
  fi
  echo "Waiting for Loki... (attempt $((attempt + 1))/$max_attempts)"
  sleep 5
  attempt=$((attempt + 1))
done

if [ $attempt -eq $max_attempts ]; then
  echo "Loki failed to start within expected time"
  docker compose logs loki
fi

# Show status
docker compose ps