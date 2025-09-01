#!/usr/bin/env python3
import argparse, random, sys, time, datetime

UA = ["curl/8.1.0","Mozilla/5.0","PostmanRuntime/7.39","python-requests/2.32"]
PATHS = ["/","/hello","/api/v1/items","/health","/missing.html","/static/app.js"]
METHODS = ["GET","POST","PUT","DELETE"]
STATUSES = [200,200,200,201,204,301,302,400,401,403,404,500,502]

def ts():
    return datetime.datetime.utcnow().strftime("%d/%b/%Y:%H:%M:%S +0000")

def access():
    ip = "127.0.0.1"
    m = random.choice(METHODS)
    p = random.choice(PATHS)
    s = random.choice(STATUSES)
    bytes_ = random.randint(50, 2048)
    ua = random.choice(UA)
    dur = f"{random.random():.3f}"
    return f'{ip} - - [{ts()}] "{m} {p} HTTP/1.1" {s} {bytes_} "-" "{ua}" {dur}\n'

def error():
    return f'[error] 123#123: *1 open() "/var/www/html/missing.html" failed (2: No such file or directory), client: 127.0.0.1, server: localhost, request: "GET /missing.html HTTP/1.1", host: "localhost"\n'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--rate", type=float, default=5.0, help="lines/sec")
    ap.add_argument("--duration", type=int, default=30, help="seconds")
    ap.add_argument("--paths", nargs="+", default=["logs/access.log","logs/error.log"])
    args = ap.parse_args()

    access_path, error_path = args.paths[0], (args.paths[1] if len(args.paths)>1 else None)
    t_end = time.time() + args.duration
    while time.time() < t_end:
        # write 1..rate lines per second
        n = max(1, int(random.gauss(args.rate, args.rate/3)))
        with open(access_path, "a") as fa:
            for _ in range(n):
                fa.write(access())
        if error_path and random.random() < 0.2:
            with open(error_path, "a") as fe:
                fe.write(error())
        time.sleep(1)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(0)
