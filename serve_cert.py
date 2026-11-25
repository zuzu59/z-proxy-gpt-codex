from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

CERT_PATH = Path("/cert/litellm.crt")


class CertificateHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        if self.path != "/litellm.crt":
            self.send_error(404)
            return

        certificate = CERT_PATH.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", "application/x-pem-file")
        self.send_header("Content-Length", str(len(certificate)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(certificate)

    def log_message(self, format: str, *args: object) -> None:
        print(f"{self.client_address[0]} - {format % args}", flush=True)


HTTPServer(("0.0.0.0", 4001), CertificateHandler).serve_forever()
