from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path

FILES = {
    "/litellm.crt": (Path("/cert/litellm.crt"), "application/x-pem-file"),
    "/install_litllm_pi.sh": (Path("/scripts/install_litllm_pi.sh"), "text/x-shellscript; charset=utf-8"),
}


class CertificateHandler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:
        resource = FILES.get(self.path)
        if resource is None:
            self.send_error(404)
            return

        file_path, content_type = resource
        content = file_path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(content)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(content)

    def log_message(self, format: str, *args: object) -> None:
        print(f"{self.client_address[0]} - {format % args}", flush=True)


HTTPServer(("0.0.0.0", 4001), CertificateHandler).serve_forever()
