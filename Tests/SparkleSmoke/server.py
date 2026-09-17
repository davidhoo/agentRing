"""Local-only fixture server. An OS-assigned port avoids collisions with user services."""
import functools
import http.server
import pathlib
import sys

root = pathlib.Path(sys.argv[1])
handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(root / "feed"))
with http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler) as server:
    (root / "port").write_text(str(server.server_port))
    server.serve_forever()
