"""Serve Excalibur with waitress behind HTTP basic auth.

Excalibur has no login of its own, so every path except /healthz needs the
username and password from EXCALIBUR_USERNAME / EXCALIBUR_PASSWORD.
"""
import base64
import hmac
import os
import sys

import railway_patch  # noqa: F401  (must load before the app)
from excalibur import configuration as conf
from excalibur.utils.database import initialize_database
from excalibur.www.app import create_app
from sqlalchemy import text
from waitress import serve

USER = os.environ["EXCALIBUR_USERNAME"].encode()
PASSWORD = os.environ["EXCALIBUR_PASSWORD"].encode()
PORT = int(os.environ.get("PORT", "8080"))
THREADS = int(os.environ.get("EXCALIBUR_THREADS", "4"))
MAX_UPLOAD = int(os.environ.get("EXCALIBUR_MAX_UPLOAD_MB", "100")) * 1024 * 1024


def health(environ, start_response):
    from excalibur.settings import engine

    try:
        with engine.connect() as c:
            c.execute(text("SELECT 1"))
    except Exception as e:  # database unreadable: fail the health check
        start_response("503 Service Unavailable", [("Content-Type", "text/plain")])
        return [("db error: %s\n" % type(e).__name__).encode()]
    start_response("200 OK", [("Content-Type", "text/plain"), ("Cache-Control", "no-store")])
    return [b"ok\n"]


def authorized(environ):
    header = environ.get("HTTP_AUTHORIZATION", "")
    if not header.lower().startswith("basic "):
        return False
    try:
        user, _, pw = base64.b64decode(header[6:].strip()).partition(b":")
    except Exception:
        return False
    ok_user = hmac.compare_digest(user, USER)
    ok_pw = hmac.compare_digest(pw, PASSWORD)
    return ok_user and ok_pw


def protect(app):
    def wrapped(environ, start_response):
        if environ.get("PATH_INFO") == "/healthz":
            return health(environ, start_response)
        if not authorized(environ):
            start_response("401 Unauthorized", [
                ("Content-Type", "text/plain"),
                ("WWW-Authenticate", 'Basic realm="Excalibur", charset="UTF-8"'),
            ])
            return [b"Login required\n"]
        return app(environ, start_response)

    return wrapped


def main():
    initialize_database()
    app = create_app(conf)
    app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD
    print("railway_serve: Excalibur on 0.0.0.0:%d (%d threads)" % (PORT, THREADS), flush=True)
    serve(
        protect(app),
        host="0.0.0.0",
        port=PORT,
        threads=THREADS,
        ident="Excalibur",
        trusted_proxy="*",
        trusted_proxy_headers="x-forwarded-proto x-forwarded-host x-forwarded-port",
        clear_untrusted_proxy_headers=True,
        max_request_body_size=MAX_UPLOAD + 1024 * 1024,
    )
    return 1  # serve() only returns on failure


if __name__ == "__main__":
    sys.exit(main())
