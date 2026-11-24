[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template/excalibur?utm_medium=integration&utm_source=button&utm_campaign=excalibur)

# Excalibur on Railway

One-click [Excalibur](https://github.com/camelot-dev/excalibur) on [Railway](https://railway.com): a web interface to extract tables from text-based PDFs into CSV, Excel, JSON or HTML, powered by [Camelot](https://camelot-py.readthedocs.io/) 2.

- **Version:** Excalibur **1.2.1** (upstream commit `1f8bff8`). Upstream publishes no container image, so the `Dockerfile` downloads that exact release tarball (checked by SHA-256) and installs upstream's frozen `uv.lock` on `python:3.12.16-slim@sha256:5e2bdb1b…`.
- **One service, no prompts.** HTTP basic auth protects every page, because Excalibur has no login of its own. `/healthz` stays open for Railway's health check.
- **Data:** the SQLite database, the config (with a random Flask secret written on first boot) and all uploads and exports are on the volume at `/data`.

## After deploy

Open the public URL and sign in as `admin` with the `EXCALIBUR_PASSWORD` value from the service's **Variables** tab. Upload a PDF, choose the pages, autodetect or draw the tables, pick Lattice or Stream, then download the data. Scanned PDFs don't work, because Excalibur has no OCR.

## Variables

| Variable | Default | What it does |
|---|---|---|
| `EXCALIBUR_USERNAME` | `admin` | Basic-auth user name |
| `EXCALIBUR_PASSWORD` | generated (`${{secret(24)}}`) | Basic-auth password. The service refuses to start if it's empty |
| `PORT` | `8080` | Port the server listens on |

Optional, not set by the template: `EXCALIBUR_MAX_UPLOAD_MB` (default `100`), `EXCALIBUR_THREADS` (web threads, default `4`).

## Memory and restarts

- Fits Railway's 0.5 GB / 1 vCPU plan. A 40-page extraction peaked at about 330 MB, and the service idles at about 100 MB. Native thread pools (OpenCV, OpenBLAS) are capped to the service's CPU quota, not the host's.
- If an extraction job is killed (for example out of memory on a huge PDF), the page shows an error instead of "Processing" forever, and later jobs still run.
- If the web server dies, the container exits non-zero, so Railway's `ON_FAILURE` restart policy brings it back.

## What this wrapper changes from upstream

- Serves with [waitress](https://docs.pylonsproject.org/projects/waitress/) instead of Flask's development server.
- Basic auth in front of the app (`railway_serve.py`).
- Moves the uploads folder from inside the Python package to `/data/uploads`, so files survive redeploys.
- Writes a random `secret_key` instead of upstream's literal `secret_key`.
- `railway_patch.py`: records an error when a job's worker process is killed, and restarts the task pool if its own worker dies.
- Leaves out upstream's optional Celery/MySQL mode, because the default sequential mode is enough for one instance.

## Updates

Railway tells everyone who deployed this template when `main` changes, and you choose when to apply it. Each version is listed in [`CHANGELOG.md`](CHANGELOG.md), with breaking changes first. Your data stays on the volume across updates.

## Licence

Excalibur is MIT licensed (Camelot Developers). The wrapper files in this repo are MIT too.
