#!/usr/bin/env bash
set -euo pipefail

echo "== mini-ELK reset =="
read -r -p "This will STOP containers and DELETE ES/Kibana data. Continue? [y/N] " yn
[[ "${yn:-N}" =~ ^[yY]$ ]] || { echo "Aborted."; exit 1; }

stack_name="$(basename "$(pwd)")"
es_svc="${ES_SVC:-elasticsearch}"
kb_svc="${KB_SVC:-kibana}"
es_container="${ES_CONTAINER:-es-mini}"   # adjust if your compose uses a different container_name

echo "[1/7] Compose down & purge volumes..."
docker compose down -v || true
docker volume rm "${stack_name}_esdata" 2>/dev/null || true
docker volume rm "${stack_name}_kibanadata" 2>/dev/null || true

echo "[2/7] Generate fresh passwords..."
ELASTIC_PW="$(openssl rand -hex 24)"
KIBANA_SYS_PW="$(openssl rand -hex 24)"

echo "[3/7] Write .env (compose will read it)"
cat > .env <<EOF
ELASTIC_VERSION=8.15.0
ELASTIC_PASSWORD=${ELASTIC_PW}
ELASTICSEARCH_USERNAME=kibana_system
KIBANA_SYSTEM_PASSWORD=${KIBANA_SYS_PW}
ES_HTTP=9200
KIBANA_HTTP=5601
EOF

echo "[4/7] Bring stack up..."
docker compose up -d

echo "[5/7] Wait for ES HTTP..."
until curl -fsS "http://localhost:9200" >/dev/null 2>&1; do sleep 2; done

echo "[6/7] Health (expect yellow on single-node)..."
curl -fsS -u elastic:"$ELASTIC_PW" \
  "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=60s" | sed 's/.*/[ES] &/'

echo
echo "== NEXT STEPS =="
echo " elastic (admin) password:      ${ELASTIC_PW}"
echo " kibana_system (kibana->ES):    ${KIBANA_SYS_PW}"
echo
echo "1) Set kibana_system inside ES to MATCH .env:"
echo "   docker compose exec ${es_svc} bin/elasticsearch-reset-password -u kibana_system -i"
echo "   (paste: ${KIBANA_SYS_PW})"
echo "2) Restart Kibana:"
echo "   docker compose restart ${kb_svc}"
echo
echo "Tip: export env into your shell before demo:"
echo "   set -a; source .env; set +a"
