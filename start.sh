#!/bin/sh
# Start Excalibur on Railway: data on /data, thread caps from the cgroup,
# a random Flask key on first boot, then waitress as an unprivileged user.
set -eu

DATA=/data
: "${PORT:=8080}"
: "${EXCALIBUR_USERNAME:=admin}"
if [ -z "${EXCALIBUR_PASSWORD:-}" ]; then
  echo "excalibur-start: EXCALIBUR_PASSWORD is empty; refusing to serve PDFs without a login" >&2
  exit 1
fi
export PORT EXCALIBUR_USERNAME EXCALIBUR_PASSWORD

# CPUs this service may use (cgroup v2 cpu.max), not the host's count.
cpus=1
if [ -r /sys/fs/cgroup/cpu.max ]; then
  read -r quota period < /sys/fs/cgroup/cpu.max || true
  if [ "${quota:-max}" != "max" ] && [ -n "${period:-}" ]; then
    cpus=$(( (quota + period - 1) / period ))
  else
    cpus=$(nproc 2>/dev/null || echo 2)
  fi
fi
[ "$cpus" -lt 1 ] && cpus=1
[ "$cpus" -gt 4 ] && cpus=4
export OMP_NUM_THREADS="$cpus" OPENBLAS_NUM_THREADS="$cpus" MKL_NUM_THREADS="$cpus" \
       NUMEXPR_MAX_THREADS="$cpus" NUMEXPR_NUM_THREADS="$cpus" OPENCV_FOR_THREADS_NUM="$cpus" \
       MALLOC_ARENA_MAX=2
: "${EXCALIBUR_THREADS:=4}"
: "${EXCALIBUR_MAX_UPLOAD_MB:=100}"
export EXCALIBUR_THREADS EXCALIBUR_MAX_UPLOAD_MB

mkdir -p "$DATA/uploads"
export EXCALIBUR_HOME="$DATA"
cfg="$DATA/excalibur.cfg"
if [ ! -s "$cfg" ]; then
  # Same defaults upstream writes on first run, with a random Flask secret
  # instead of the literal "secret_key".
  key=$(python -c 'import secrets; print(secrets.token_hex(32))')
  cat > "$cfg.tmp" <<CFG
[core]
excalibur_home = $DATA
executor = SequentialExecutor
sql_alchemy_conn = sqlite:///$DATA/excalibur.db
logging_level = INFO

[webserver]
web_server_host = 0.0.0.0
web_server_port = $PORT
secret_key = $key
CFG
  mv "$cfg.tmp" "$cfg"
  echo "excalibur-start: wrote $cfg"
fi
chown -R 1000:1000 "$DATA"

cd /app
echo "excalibur-start: cpus=$cpus threads=$EXCALIBUR_THREADS port=$PORT"
# Run the server as a child (not PID 1) so a crash or an out-of-memory kill
# of the server ends this script with a non-zero code and Railway restarts it.
setpriv --reuid=1000 --regid=1000 --init-groups -- /app/.venv/bin/python -m railway_serve &
child=$!
trap 'kill -TERM "$child" 2>/dev/null; wait "$child"; exit 0' TERM INT
set +e
wait "$child"
code=$?
echo "excalibur-start: server exited with code $code" >&2
[ "$code" -eq 0 ] && code=1
exit "$code"
