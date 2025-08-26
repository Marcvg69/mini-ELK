set -euo pipefail

echo "==> Bringing stack down and removing volumes (this deletes ES data)"
docker compose down -v

echo "==> Bringing stack up"
docker compose up -d

echo "==> Waiting for Elasticsearch to start..."
# simple wait loop
for i in {1..30}; do
  if curl -s "http://localhost:9200" >/dev/null; then
    break
  fi
  sleep 2
done

echo "==> Checking cluster health (auth as elastic)"
# make sure your shell has ELASTIC_PASSWORD; otherwise source .env before running this script
curl -u elastic:"${ELASTIC_PASSWORD:-changeme}" "http://localhost:9200/_cluster/health?pretty" || true

echo "==> Creating a new Kibana service account token"
TOKEN=$(docker exec -i es-mini /usr/share/elasticsearch/bin/elasticsearch-service-tokens create elastic/kibana kibana-service | awk '{print $NF}')
echo
echo "----- COPY THIS INTO YOUR .env AS KIBANA_SERVICE_TOKEN -----"
echo "$TOKEN"
echo "------------------------------------------------------------"
echo

echo "==> (Next) Put the token into .env:"
echo "KIBANA_SERVICE_TOKEN=$TOKEN"
echo
echo "==> Then restart Kibana:"
echo "docker compose restart kibana"
echo
echo "==> After Kibana restarts, test from inside the Kibana container:"
echo "docker compose exec kibana sh -lc 'curl -i -s -H \"Authorization: Bearer \$ELASTICSEARCH_SERVICEACCOUNTTOKEN\" http://elasticsearch:9200/'"
