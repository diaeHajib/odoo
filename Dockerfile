# ── Nyx Odoo deployment image ────────────────────────────────────────────────
# Runs THIS repository's source on top of the official `odoo:19.0` runtime.
# The official image already provides the expensive parts (wkhtmltopdf for PDF
# reports, node-less, rtlcss, fonts, postgres client), so we only overlay the
# fork's code instead of rebuilding an Odoo install from scratch.
#
# HOW THE FORK WINS OVER THE IMAGE'S OWN ODOO PACKAGE
#   * PYTHONPATH=/opt/odoo makes `/usr/bin/odoo` (from the .deb) resolve
#     `import odoo` to /opt/odoo first.
#   * the guard below FAILS THE BUILD if that isn't true, so a mis-built image
#     can never silently run the stock package.
#
# BUILD ARG
#   NYX_INSTALL_REQS=1 -> also run `pip install -r requirements.txt`.
#     Default 0: on a pristine 19.0 branch the .deb already satisfies those
#     deps, and pip would want to compile psycopg2/python-ldap/lxml (the
#     runtime image has no dev headers). Flip it ON only if you ADD a python
#     dependency, and expect a slower, much heavier build.
FROM odoo:19.0

ARG NYX_INSTALL_REQS=0

USER root

# 1. Fork source (.dockerignore keeps the ~17GB .git out of the build context)
COPY --chown=odoo:odoo . /opt/odoo

# 2. Optional python requirements for this branch (see BUILD ARG above)
RUN if [ "$NYX_INSTALL_REQS" = "1" ]; then \
      apt-get update && apt-get install -y --no-install-recommends \
        build-essential libxml2-dev libxslt1-dev libpq-dev libsasl2-dev \
        libldap2-dev libev-dev libjpeg-dev zlib1g-dev && \
      pip3 install --no-cache-dir --break-system-packages -r /opt/odoo/requirements.txt && \
      apt-get clean && rm -rf /var/lib/apt/lists/* ; \
    else \
      echo "[nyx] NYX_INSTALL_REQS=0 - using the odoo:19.0 deb-provided python deps"; \
    fi

# 3. GUARDS: prove the fork is the code that will actually run
RUN python3 -c "import odoo; p = odoo.__file__; assert p.startswith('/opt/odoo/'), 'WRONG SOURCE -> ' + p; print('[nyx] fork source in use ->', p)" \
 && python3 -c "import lxml, psycopg2, gevent, PIL, passlib, babel; print('[nyx] runtime deps present')"

ENV PYTHONPATH=/opt/odoo \
    ODOO_ADDONS_PATH=/opt/odoo/addons,/opt/odoo/odoo/addons,/mnt/extra-addons

# 4. Wrapper entrypoint: turns env vars into Odoo CLI args, then hands off to
#    the official /entrypoint.sh (waits for postgres, applies db_* settings).
COPY --chown=root:root docker/odoo-entrypoint.sh /usr/local/bin/nyx-odoo-entrypoint.sh
RUN chmod 0755 /usr/local/bin/nyx-odoo-entrypoint.sh

# filestore (attachments) lives in /var/lib/odoo -> mount persistent storage there
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]

USER odoo
EXPOSE 8069 8071 8072

ENTRYPOINT ["/usr/local/bin/nyx-odoo-entrypoint.sh"]
CMD ["odoo"]
