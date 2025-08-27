#!/usr/bin/env bash
set -euo pipefail

echo "== mini-ELK reset =="
echo "This will STOP containers and DELETE Elasticsearch/Kibana data volumes."
read -r -p "Continue? [y/N] " yn
if [[ "${yn:-N}" != [yY] ]]; then
  echo "Aborted."
  exit 1
fi

echo "[1/6] Stopping and removing containers..."
docker compose down -v || true

echo "[2/6] Removing named volumes (if present)..."
docker volume rm "$(basename "$(pwd)")_esdata" 2>/dev/null || true
docker volume rm "$(basename "$(pwd)")_kibanadata" 2>/dev/null || true

echo "[3/6] Generating passwords (hex, alphanumeric-only)..."
ELASTIC_PW="$(openssl rand -hex 24)"
KIBANA_SYS_PW="$(openssl rand -hex 24)"

echo "[4/6] Writing fresh .env..."
cat > .env <<EOF
# =========================================
# Elastic stack versions
# =========================================
ELASTIC_VERSION=8.15.0

# =========================================
# Elasticsearch built-in 'elastic' superuser password
# (applies on FIRST BOOT of a fresh data path)
# =========================================
ELASTIC_PASSWORD=${ELASTIC_PW}

# =========================================
# Kibana -> Elasticsearch credentials
# Use the built-in 'kibana_system'.
# We'll set this INSIDE Elasticsearch after boot.
# =========================================
ELASTICSEARCH_USERNAME=kibana_system
KIBANA_SYSTEM_PASSWORD=${KIBANA_SYS_PW}

# =========================================
# Ports
# =========================================
ES_HTTP=9200
KIBANA_HTTP=5601
EOF

echo "[5/6] Booting fresh stack..."
docker compose up -d

echo "[6/6] Waiting for Elasticsearch to report healthy..."
for i in {1..90}; do
  if docker inspect --format='{{.State.Health.Status}}' es-mini 2>/dev/null | grep -q healthy; then
    echo "Elasticsearch is healthy."
    break
  fi
  sleep 2
done

echo
echo "== NEXT STEPS =="
echo "Elastic credentials saved to .env"
echo "  ELASTIC_PASSWORD=${ELASTIC_PW}"
echo "  KIBANA_SYSTEM_PASSWORD=${KIBANA_SYS_PW}"
echo
echo "Now set kibana_system inside ES to MATCH .env:"
echo "  docker compose exec elasticsearch bin/elasticsearch-reset-password -u kibana_system -i"
echo "  (paste: ${KIBANA_SYS_PW})"
echo
echo "Then restart Kibana:"
echo "  docker compose restart kibana"
