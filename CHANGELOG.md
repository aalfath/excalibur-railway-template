# Changelog

## 1.2.1 (2026-11-24)

First release of this template.

- Excalibur 1.2.1 (upstream commit `1f8bff8`), built with uv from upstream's frozen lock on `python:3.12.16-slim`.
- Served by waitress behind HTTP basic auth (`EXCALIBUR_USERNAME` / `EXCALIBUR_PASSWORD`); `/healthz` stays open for Railway's health check.
- SQLite database, config (with a random Flask secret) and uploaded PDFs on the `/data` volume.
- Thread pools capped from the service's CPU quota; a killed extraction job shows an error instead of "Processing" forever.
