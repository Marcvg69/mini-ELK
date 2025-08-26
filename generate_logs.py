import random, time, datetime, pathlib

LOG = pathlib.Path("logs/access.log")
LOG.parent.mkdir(parents=True, exist_ok=True)

ips = ["192.168.0.12", "10.0.0.5", "66.249.66.1", "172.16.1.10", "203.0.113.9"]
methods = ["GET", "POST"]
urls = ["/", "/login", "/products", "/products/42", "/search?q=elk", "/api/v1/orders"]
agents = [
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
    "curl/8.1.0",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64)",
]

def line():
    ip = random.choice(ips)
    ident = "-"
    user = "-"
    now = datetime.datetime.utcnow().strftime("%d/%b/%Y:%H:%M:%S +0000")
    method = random.choice(methods)
    url = random.choice(urls)
    status = random.choices([200, 201, 301, 400, 401, 403, 404, 500], weights=[70,5,5,5,3,3,6,3])[0]
    size = random.randint(200, 5000)
    ref = "-"
    ua = random.choice(agents)
    rt = random.random() * 0.8 + (0.7 if status >= 500 else 0.0)  # slower if 5xx
    return f'{ip} - {ident} {user} [{now}] "{method} {url} HTTP/1.1" {status} {size} "{ref}" "{ua}" {rt:.3f}\n'

print("Writing synthetic access logs to logs/access.log (Ctrl+C to stop)…")
with LOG.open("a", encoding="utf-8") as f:
    try:
        while True:
            f.write(line())
            f.flush()
            time.sleep(random.uniform(0.05, 0.3))
    except KeyboardInterrupt:
        print("Stopped.")
