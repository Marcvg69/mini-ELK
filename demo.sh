#!/usr/bin/env bash
# demo.sh
# ------------------------------------------------------------
# Bring stack up, wait for ES, append a couple of access lines
# and one error line, then query Elasticsearch to show parsed
# docs in nginx_access-* and nginx_error-*.
# ------------------------------------------------------------
# Fail early if password not set
if [ -z "${ELASTIC_PASSWORD:-}" ]; then
  echo "ERROR: ELASTIC_PASSWORD is not set. Export it first:"
  echo "  export ELASTIC_PASSWORD=yourpassword"
  exit 1
fi

set -euo pipefail

echo "==> Bringing up the stack..."
docker compose up -d

echo "==> Wait for Elasticsearch..."
until curl -u elastic:"${ELASTIC_PASSWORD:-changeme}" -s \
  "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=60s" >/dev/null; do
  sleep 3
done
echo "Elasticsearch is up."

echo "==> Make sure log files exist"
mkdir -p logs
touch logs/access.log logs/error.log

echo "==> Append test access + error lines"
printf '127.0.0.1 - - [%s] "GET /hello HTTP/1.1" 200 123 "-" "curl/8.1.0" 0.045\n' \
  "$(date -u +'%d/%b/%Y:%H:%M:%S +0000')" >> logs/access.log
sleep 1
printf '127.0.0.1 - - [%s] "GET /health HTTP/1.1" 404 321 "-" "curl/8.1.0" 0.012\n' \
  "$(date -u +'%d/%b/%Y:%H:%M:%S +0000')" >> logs/access.log
echo '[error] 123#123: *1 open() "/var/www/html/missing.html" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /missing.html HTTP/1.1", host: "localhost"' >> logs/error.log

echo "==> Give Logstash a few seconds to ingest..."
sleep 5

echo "==> Show indices"
curl -u elastic:"$ELASTIC_PASSWORD" -s "http://localhost:9200/_cat/indices?v" | egrep 'nginx_access|nginx_error' || true

echo "==> Search nginx_access-*"
curl -u elastic:"$ELASTIC_PASSWORD" -s \
  "http://localhost:9200/nginx_access-*/_search?size=5&sort=@timestamp:desc&pretty"

echo "==> Search nginx_error-*"
curl -u elastic:"$ELASTIC_PASSWORD" -s \
  "http://localhost:9200/nginx_error-*/_search?size=5&sort=@timestamp:desc&pretty"
