#!/usr/bin/env bash
set -euo pipefail

echo "== mini-ELK reset =="
echo "This will STOP containers and DELETE Elasticsearch/Kibana data volumes."
read -r -p "Continue? [y/N] " yn
if [[ "${yn:-N}" != "y" && "${yn:-N}" != "Y" ]]; then
  echo "Aborted."
  exit 1
fi

# Bring down stack and delete anonymous/named volumes
echo "[1/5] Stopping and removing containers..."
docker compose down -v || true

# Best effort: remove named volumes if they still exist
echo "[2/5] Removing named volumes (if present)..."
docker volume rm "$(basename "$(pwd)")_esdata" 2>/dev/null || true
docker volume rm "$(basename "$(pwd)")_kibanadata" 2>/dev/null || true

# Generate strong alphanumeric passwords (no special chars to avoid shell/globbing issues)
gen_pw() { tr -dc 'A-Za-z0-9' </dev/urandom | head -c 24; echo; }
ELASTIC_PW="$(gen_pw)"
KIBANA_SYS_PW="$(gen_pw)"

echo "[3/5] Writing fresh .env..."
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
# You will manually reset the password in ES to match this value.
# =========================================
ELASTICSEARCH_USERNAME=kibana_system
KIBANA_SYSTEM_PASSWORD=${KIBANA_SYS_PW}

# =========================================
# Ports
# =========================================
ES_HTTP=9200
KIBANA_HTTP=5601
EOF

echo "[4/5] Booting fresh stack..."
docker compose up -d

echo "[5/5] Waiting for Elasticsearch to report healthy (this can take ~30–60s)..."
# Simple wait loop
for i in {1..60}; do
  if docker inspect --format='{{json .State.Health.Status}}' es-mini 2>/dev/null | grep -q healthy; then
    echo "Elasticsearch is healthy."
    break
  fi
  sleep 2
done

echo
echo "== NEXT STEPS =="
echo "1) Verify you can auth as 'elastic' with the password from .env:"
echo "   curl -s -u elastic:${ELASTIC_PW} http://localhost:9200 | jq .cluster_name"
echo
echo "2) Manually set the 'kibana_system' password INSIDE Elasticsearch to match .env:"
echo "   docker compose exec elasticsearch bin/elasticsearch-reset-password -u kibana_system"
echo "   When prompted, enter this EXACT password:"
echo "     ${KIBANA_SYS_PW}"
echo
echo "3) Restart Kibana so it picks up the working credentials:"
echo "   docker compose restart kibana"
echo
echo "Credentials written to .env:"
echo "  ELASTIC_PASSWORD=${ELASTIC_PW}"
echo "  KIBANA_SYSTEM_PASSWORD=${KIBANA_SYS_PW}"
