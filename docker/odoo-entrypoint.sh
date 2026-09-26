#!/bin/bash
# ── Nyx Odoo entrypoint wrapper ──────────────────────────────────────────────
# Translates environment variables (injected by Coolify) into Odoo CLI args,
# then executes the official odoo:19.0 entrypoint. That entrypoint:
#   * builds --db_host/--db_port/--db_user/--db_password from HOST/PORT/USER/PASSWORD
#     (only when the config file doesn't already define them),
#   * waits for postgres (wait-for-psql.py), then `exec odoo "$@" "${DB_ARGS[@]}"`.
#
# GOTCHA: Odoo declares the DB master password as a FileOnlyOption
# (odoo/tools/config.py: parser.add_option(FileOnlyOption(dest='admin_passwd'))),
# so `--admin-passwd` does NOT exist and makes Odoo exit 2 at startup. It must be
# written into the config file instead -> that is what the RC block below does.
set -e

: "${ODOO_DB_NAME:=odoo}"
: "${ODOO_WORKERS:=0}"
: "${ODOO_MAX_CRON_THREADS:=1}"
: "${ODOO_DB_MAXCONN:=16}"
: "${ODOO_PROXY_MODE:=1}"
: "${ODOO_LOG_LEVEL:=info}"
: "${ODOO_ADDONS_PATH:=/opt/odoo/addons,/opt/odoo/odoo/addons,/opt/odoo/custom_addons,/mnt/extra-addons}"
: "${ODOO_DATA_DIR:=/var/lib/odoo}"

# ---- config file: base image conf + the FileOnlyOptions we need -------------
BASE_RC=/etc/odoo/odoo.conf
RC=/tmp/nyx-odoo.conf
if [ -r "$BASE_RC" ]; then
  # keep everything, drop any (commented or not) admin_passwd line, then append ours
  grep -v -E '^[[:space:]]*;?[[:space:]]*admin_passwd[[:space:]]*=' "$BASE_RC" > "$RC" 2>/dev/null || cp "$BASE_RC" "$RC"
else
  printf '[options]\n' > "$RC"
fi
if [ -n "${ODOO_ADMIN_PASSWD:-}" ]; then
  printf 'admin_passwd = %s\n' "$ODOO_ADMIN_PASSWD" >> "$RC"
fi
if [ -n "${ODOO_DB_FILTER:-}" ]; then
  printf 'dbfilter = %s\n' "$ODOO_DB_FILTER" >> "$RC"
fi
export ODOO_RC="$RC"

# ---- normal CLI options -----------------------------------------------------
ARGS=(odoo
  "--addons-path=${ODOO_ADDONS_PATH}"
  "--data-dir=${ODOO_DATA_DIR}"
  "--database=${ODOO_DB_NAME}"
  "--db-filter=^${ODOO_DB_NAME}$"
  "--db_maxconn=${ODOO_DB_MAXCONN}"
  "--workers=${ODOO_WORKERS}"
  "--max-cron-threads=${ODOO_MAX_CRON_THREADS}"
  "--log-level=${ODOO_LOG_LEVEL}"
)

# behind Traefik (TLS terminates at the proxy) Odoo must trust X-Forwarded-*
[ "${ODOO_PROXY_MODE}" = "1" ] && ARGS+=(--proxy-mode)
# hide the database-manager / DB list (prod hardening)
[ "${ODOO_LIST_DB}" = "0" ] && ARGS+=(--no-database-list)

# ---- startup marker ---------------------------------------------------------
# NB: print __path__, never __file__: Odoo is a PEP 420 namespace package and
#      odoo.__file__ is None even in a perfectly good install.
FORK_SRC=$(python3 -c 'import odoo, odoo.release as r; print(r.version, list(odoo.__path__)[0])' 2>/dev/null || echo 'unknown')
echo "[nyx-odoo] db=${ODOO_DB_NAME} workers=${ODOO_WORKERS} cron=${ODOO_MAX_CRON_THREADS} proxy=${ODOO_PROXY_MODE} listdb=${ODOO_LIST_DB:-default}"
echo "[nyx-odoo] version/path=${FORK_SRC}"
echo "[nyx-odoo] admin_passwd set=${ODOO_ADMIN_PASSWD:+yes}"

exec /entrypoint.sh "${ARGS[@]}"
