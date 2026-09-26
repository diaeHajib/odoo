# custom_addons — Eden's Odoo modules

Everything in this directory is on Odoo's `addons-path` in **all** environments
(`/opt/odoo/custom_addons` in the containers, `E:/odoo/odoo/custom_addons` locally).
One directory per module, and that is the whole mechanism — commit here and the next
deploy ships it.

## The dev → staging → prod loop

```
local Odoo (E:/odoo)  →  git push origin dev  →  staging auto-deploys
                                              →  test in https://odoo-dev.46.224.134.60.sslip.io
                                              →  merge dev → prod  →  prod auto-deploys
```

1. **Develop locally** — module lives in `custom_addons/<module_name>/`, then
   `python odoo-bin -c E:/odoo/odoo-local.conf -u <module_name> --stop-after-init`
   (or run with `-c ... --dev=all` and use Apps → Update Apps List).
2. **Push to `dev`** — Coolify auto-deploys staging on push (GitHub App webhook).
   Install/upgrade the module there on a copy of real data: *Apps → Update Apps List → Install*.
3. **Validate** — check behaviour plus logs in Coolify → odoo-dev → Logs.
4. **Promote** — `git checkout prod && git merge dev && git push` → production redeploys.
   The module is *shipped* but not *installed*; install it in prod when you're ready.

## Rules that keep this safe

- **Never edit Odoo core in place** (`addons/`, `odoo/`) — those are upstream files and every
  `git merge upstream/19.0` would fight you. Override via inheritance (`_inherit`) in your own
  module instead. Add files *only* under `custom_addons/`.
- **Bump `version` in `__manifest__.py`** for every change you push, otherwise Odoo may skip the
  upgrade. Format: `19.0.<module>.x.y.z`.
- **Migrations**: add `migrations/<version>/pre-migrate.py` etc. when a change alters stored data.
- **Data vs code**: keep XML data files idempotent; use `noupdate="1"` for records users may edit.
- **The staging DB is disposable; the production DB is not.** Test destructive things on staging
  first, and never point a local instance at the production database.
