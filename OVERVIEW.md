# Deploy and Host Excalibur on Railway

Excalibur is an open-source web interface for pulling tables out of PDFs. You upload a text-based PDF, pick the pages, let it detect tables or draw a box around them, then download the result as CSV, Excel, JSON or HTML. It runs on Camelot 2, the Python table-extraction library, and is MIT licensed.

## About Hosting Excalibur

This template deploys one service, **Excalibur** 1.2.1, built from the public repo `aalfath/excalibur-railway-template`. Upstream publishes no container image, so the repo builds the pinned v1.2.1 release with upstream's own locked dependencies. Excalibur has no login of its own, so the template puts HTTP basic auth in front of every page. The user is `admin` and the password is generated on deploy. The SQLite database, the config with a random Flask secret, and every uploaded PDF and export live on a Railway volume at `/data`. The app serves on port 8080 with a health check at `/healthz`. There are no prompts to fill in.

## Common Use Cases

* Turn tables in bank statements, invoices and reports into CSV or Excel files
* Save extraction settings as a rule and reuse them on PDFs with the same layout
* Give a team a private, self-hosted PDF-to-spreadsheet tool instead of an online converter

## Dependencies for Excalibur Hosting

* A Railway volume for the database, uploads and exports (included)
* Nothing else: no database service, API key or outside service is needed

### Deployment Dependencies

* Excalibur source and releases: https://github.com/camelot-dev/excalibur (v1.2.1)
* Excalibur documentation: https://excalibur-py.readthedocs.io/
* Camelot, the extraction engine: https://camelot-py.readthedocs.io/
* Template repo: https://github.com/aalfath/excalibur-railway-template

### Implementation Details

**After deploy:** open the service's public URL. Your browser asks for a login: the user is `admin` and the password is the `EXCALIBUR_PASSWORD` variable on the Excalibur service (Variables tab). To change either one, edit `EXCALIBUR_USERNAME` or `EXCALIBUR_PASSWORD` and redeploy.

**Using it:** upload a PDF and enter the pages (for example `1,3-5`). Open the workspace, click "Autodetect tables" or draw table areas, choose Lattice (tables with ruling lines) or Stream (tables aligned by spaces), then "View and download data". Excalibur reads only text-based PDFs, not scans: it has no OCR.

**Memory:** it fits Railway's 0.5 GB plan. In our test, a 40-page job peaked at about 330 MB, with about 100 MB in use while idle. Very large or dense PDFs need more memory. If an extraction job is killed for lack of memory, the page shows an error instead of "Processing" forever. Try fewer pages at a time, or give the service more RAM. Uploads are capped at 100 MB (`EXCALIBUR_MAX_UPLOAD_MB`).

**Left out:** upstream's optional Celery and MySQL mode for distributed work. The built-in sequential mode, one job at a time, is what the app uses by default and is enough for one instance.

**Updates:** the service builds from the template repo. When we bump Excalibur there, Railway shows you an update notice and you choose when to apply it. Read `CHANGELOG.md` in the repo first. Your data stays on the volume.

## Why Deploy Excalibur on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Excalibur on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
