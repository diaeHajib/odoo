# ── Nyx Odoo deployment image ────────────────────────────────────────────────
# Runs THIS repository's source on top of the official `odoo:19.0` runtime.
# The official image already provides the expensive parts (wkhtmltopdf for PDF
# reports, node-less, rtlcss, fonts, postgres client), so we only overlay the
# fork's code instead of rebuilding an Odoo install from scratch.
#
# HOW THE FORK WINS OVER THE IMAGE'S OWN ODOO TREE  (read before editing!)
#   * Odoo uses IMPLICIT NAMESPACE PACKAGES (PEP 420): the source tree has NO
#     odoo/__init__.py, and neither does the image's /usr/lib/python3/dist-packages/odoo.
#     Python therefore MERGES every `odoo` directory found on sys.path into one
#     namespace, and the FIRST entry wins per submodule.
#   * => PYTHONPATH=/opt/odoo must be set for the /opt/odoo tree to come first.
#     It is set BEFORE the guard on purpose: with it set later, the guard would
#     test the image's tree and pass/fail for the wrong reason.
#   * the guard asserts /opt/odoo/odoo is path[0] AND that a real submodule
#     (odoo.tools) loads from /opt/odoo. Never check odoo.__file__ here: for a
#     namespace package it is None.
#
# BUILD ARG
#   NYX_INSTALL_REQS=1 -> also run `pip install -r requirements.txt`.
#     Default 0: on a pristine 19.0 branch the .deb already satisfies those deps,
#     and pip would want to compile psycopg2/python-ldap/lxml (this runtime image
#     has no dev headers). Flip ON only if you ADD a python dependency.
FROM odoo:19.0

ARG NYX_INSTALL_REQS=0

USER root

# 1. Fork source first on the import path (.dockerignore keeps the ~17GB .git out)
#    custom_addons/ is where Eden's own modules live and is on the addons-path,
#    so anything committed there ships to staging/prod with the next deploy.
ENV PYTHONPATH=/opt/odoo \
    ODOO_ADDONS_PATH=/opt/odoo/addons,/opt/odoo/odoo/addons,/opt/odoo/custom_addons,/mnt/extra-addons

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

# 3. GUARDS - prove the fork is the code that will actually run.
#    Namespace-package aware: __path__ + a real submodule, never __file__.
RUN python3 -c 'import odoo, odoo.tools; p = list(odoo.__path__); print("[nyx] odoo.__path__ =", p); assert p and p[0].startswith("/opt/odoo"), "fork is not FIRST on the import path: %s" % p; t = odoo.tools.__file__; print("[nyx] odoo.tools ->", t); assert t.startswith("/opt/odoo"), "submodule loaded from the wrong tree: %s" % t; import odoo.release as r; print("[nyx] fork source in use, version", r.version)' \
 && python3 -c "import lxml, psycopg2, gevent, PIL, passlib, babel; print('[nyx] runtime deps present')"

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
