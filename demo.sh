#!/usr/bin/env bash
# demo.sh — bring up stack, generate logs, query ES
set -euo pipefail

WITH_STREAM=false
STREAM_DURATION=30

for arg in "$@"; do
  case "$arg" in
    --with-stream) WITH_STREAM=true ;;
    --duration=*)  STREAM_DURATION="${arg#*=}" ;;
    *) echo "Usage: $0 [--with-stream] [--duration=SECONDS]"; exit 1 ;;
  esac
done

# Load env from .env if not exported
if [ -z "${ELASTIC_PASSWORD:-}" ] && [ -f .env ]; then
  set -a; source .env; set +a
fi
: "${ELASTIC_PASSWORD:?ELASTIC_PASSWORD not set; run:  set -a; source .env; set +a }"

echo "==> Up stack"
docker compose up -d

echo "==> Wait for ES (yellow/green)"
until curl -fsS -u elastic:"$ELASTIC_PASSWORD" \
  "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=60s" >/dev/null; do
  sleep 2
done
echo "Elasticsearch is ready."

echo "==> Ensure logs/ exists"
mkdir -p logs
touch logs/access.log logs/error.log

echo "==> Seed a few lines"
printf '127.0.0.1 - - [%s] "GET /hello HTTP/1.1" 200 123 "-" "curl/8.1.0" 0.045\n' \
  "$(date -u +'%d/%b/%Y:%H:%M:%S +0000')" >> logs/access.log
sleep 1
printf '127.0.0.1 - - [%s] "GET /health HTTP/1.1" 404 321 "-" "curl/8.1.0" 0.012\n' \
  "$(date -u +'%d/%b/%Y:%H:%M:%S +0000')" >> logs/access.log
echo '[error] 123#123: *1 open() "/var/www/html/missing.html" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /missing.html HTTP/1.1", host: "localhost"' >> logs/error.log

echo "==> Give Logstash a moment..."
sleep 5

echo "==> Indices:"
curl -s -u elastic:"$ELASTIC_PASSWORD" "http://localhost:9200/_cat/indices?v" | egrep 'nginx_(access|error)' || true

echo "==> Sample docs (access):"
curl -s -u elastic:"$ELASTIC_PASSWORD" \
  "http://localhost:9200/nginx_access-*/_search?size=3&sort=@timestamp:desc&pretty"

echo "==> Sample docs (error):"
curl -s -u elastic:"$ELASTIC_PASSWORD" \
  "http://localhost:9200/nginx_error-*/_search?size=3&sort=@timestamp:desc&pretty"

if $WITH_STREAM; then
  if command -v python3 >/dev/null 2>&1 && [ -f generate_logs.py ]; then
    echo "==> Streaming logs for ${STREAM_DURATION}s..."
    python3 generate_logs.py --rate 5 --duration "$STREAM_DURATION" --paths logs/access.log logs/error.log || true
  else
    echo "NOTE: generate_logs.py not found; skipping stream."
  fi
fi

echo "==> Done. Open Kibana at http://localhost:5601/"
