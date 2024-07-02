import http.server
import socketserver

PORT = 8000
DIRECTORY = "C:/Users/Family/Desktop/Egg-Count/html"

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DIRECTORY, **kwargs)

with socketserver.TCPServer(("127.0.0.1", PORT), Handler) as httpd:
    print("Serving at 127.0.0.1:", PORT)
    httpd.serve_forever()
