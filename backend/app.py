#!/usr/bin/env python3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import sys

HOST = "127.0.0.1"
PORT = 3000


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        body = (
            "Hello from backend (Python)\n"
            f"path: {self.path}\n"
            f"Host: {self.headers.get('Host', '')}\n"
            f"X-Real-IP: {self.headers.get('X-Real-IP', '')}\n"
            f"X-Forwarded-For: {self.headers.get('X-Forwarded-For', '')}\n"
        ).encode("utf-8")

        self.send_response(200)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, fmt, *args):
        sys.stderr.write("[backend] %s - %s\n" % (self.address_string(), fmt % args))


def main():
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"[backend] listening on http://{HOST}:{PORT} (Ctrl+C to stop)", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[backend] stopped", flush=True)
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
