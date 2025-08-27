#!/usr/bin/env python3
# generate_logs.py
# ------------------------------------------------------------
# Generate demo Nginx-like access lines (and some errors)
# into ./logs/access.log and ./logs/error.log for Logstash.
# ------------------------------------------------------------
import time
import random
from datetime import datetime, timezone

ACCESS_PATH = "logs/access.log"
ERROR_PATH  = "logs/error.log"

METHODS = ["GET", "POST", "PUT", "DELETE"]
PATHS   = ["/", "/hello", "/health", "/api/v1/items", "/login", "/missing.html"]
UAS     = ["curl/8.1.0", "Mozilla/5.0", "k6/0.48.0"]

def httpdate():
    # e.g. 27/Aug/2025:06:46:39 +0000
    return datetime.now(timezone.utc).strftime("%d/%b/%Y:%H:%M:%S +0000")

def write_access(n=20, sleep_s=0.2):
    with open(ACCESS_PATH, "a", encoding="utf-8") as f:
        for _ in range(n):
            ip = "127.0.0.1"
            method = random.choice(METHODS)
            path = random.choice(PATHS)
            status = random.choice([200, 201, 204, 302, 400, 401, 403, 404, 500])
            bytes_ = random.randint(50, 2048)
            ua = random.choice(UAS)
            dur = round(random.uniform(0.001, 0.250), 3)
            line = f'{ip} - - [{httpdate()}] "{method} {path} HTTP/1.1" {status} {bytes_} "-" "{ua}" {dur}\n'
            f.write(line)
            f.flush()
            time.sleep(sleep_s)

def write_error():
    # simple error format; includes client/server/request/host that our grok can pick up
    msg = ('[error] 123#123: *1 open() "/var/www/html/missing.html" failed (2: No such file or directory), '
           'client: 127.0.0.1, server: localhost, request: "GET /missing.html HTTP/1.1", host: "localhost"\n')
    with open(ERROR_PATH, "a", encoding="utf-8") as f:
        f.write(msg)
        f.flush()

if __name__ == "__main__":
    print("Generating access log lines...")
    write_access(n=30, sleep_s=0.05)
    print("Writing one error line...")
    write_error()
    print("Done.")
