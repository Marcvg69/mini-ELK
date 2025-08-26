#!/usr/bin/env bash
set -e

echo "==> Bringing up the stack..."
docker compose up -d

echo "==> Wait for Elasticsearch..."
until curl -u elastic:"$ELASTIC_PASSWORD" -s "http://localhost:9200/_cluster/health?wait_for_status=yellow&timeout=60s" > /dev/null; do
  sleep 5
done
echo "Elasticsearch is up."

echo "==> Append test nginx-style logs to the correct files"
# Append to access log
echo '127.0.0.1 - - [26/Aug/2025:12:22:19 +0000] "GET /hello HTTP/1.1" 200 123 "-" "curl/8.1.0" 0.045' >> logs/nginx/access.log
echo '127.0.0.1 - - [26/Aug/2025:12:24:30 +0000] "GET /health HTTP/1.1" 404 55 "-" "curl/8.1.0" 0.012' >> logs/nginx/access.log

# Append to error log
echo '[error] 123#123: *1 open() "/var/www/html/missing.html" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /missing.html HTTP/1.1", host: "localhost"' >> logs/nginx/error.log

echo "==> Give Filebeat a few seconds to ship events..."
sleep 5

echo "==> Search for parsed nginx logs"
curl -u elastic:"$ELASTIC_PASSWORD" -s "http://localhost:9200/filebeat-*/_search?size=5&sort=@timestamp:desc&pretty" | jq .
