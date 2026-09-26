#!/bin/bash
# ── Nyx Odoo entrypoint wrapper ──────────────────────────────────────────────
# Translates environment variables (injected by Coolify) into Odoo CLI args,
# then executes the official odoo:19.0 entrypoint. That entrypoint:
#   * builds --db_host/--db_port/--db_user/--db_password from HOST/PORT/USER/PASSWORD
#     (only when the config file doesn't already define them),
#   * waits for postgres (wait-for-psql.py), then `exec odoo "$@" "${DB_ARGS[@]}"`.
# So everything we pass here is appended to the real odoo command line.
set -e

: "${ODOO_DB_NAME:=odoo}"
: "${ODOO_WORKERS:=0}"
: "${ODOO_MAX_CRON_THREADS:=1}"
: "${ODOO_DB_MAXCONN:=16}"
: "${ODOO_PROXY_MODE:=1}"
: "${ODOO_LOG_LEVEL:=info}"
: "${ODOO_ADDONS_PATH:=/opt/odoo/addons,/opt/odoo/odoo/addons,/mnt/extra-addons}"
: "${ODOO_DATA_DIR:=/var/lib/odoo}"

ARGS=(odoo
  "--addons-path=${ODOO_ADDONS_PATH}"
  "--data-dir=${ODOO_DATA_DIR}"
  "--db-filter=^${ODOO_DB_NAME}$"
  "--database=${ODOO_DB_NAME}"
  "--db_maxconn=${ODOO_DB_MAXCONN}"
  "--workers=${ODOO_WORKERS}"
  "--max-cron-threads=${ODOO_MAX_CRON_THREADS}"
  "--log-level=${ODOO_LOG_LEVEL}"
)

# behind Traefik (TLS terminates at the proxy) Odoo must trust X-Forwarded-*
[ "${ODOO_PROXY_MODE}" = "1" ] && ARGS+=(--proxy-mode)
# master password for the database manager -- NEVER baked into the image,
# supplied as a Coolify env var so it stays out of this public repo
[ -n "${ODOO_ADMIN_PASSWD:-}" ] && ARGS+=(--admin-passwd="${ODOO_ADMIN_PASSWD}")
# hide the database-manager/DB list (prod hardening); keep it on for staging
[ "${ODOO_LIST_DB}" = "0" ] && ARGS+=(--no-database-list)

FORK_SRC=$(python3 -c 'import odoo; print(odoo.__file__)' 2>/dev/null || echo 'unknown')
echo "[nyx-odoo] db=${ODOO_DB_NAME} workers=${ODOO_WORKERS} cron=${ODOO_MAX_CRON_THREADS} proxy=${ODOO_PROXY_MODE} listdb=${ODOO_LIST_DB:-default}"
echo "[nyx-odoo] source=${FORK_SRC}"

exec /entrypoint.sh "${ARGS[@]}"
