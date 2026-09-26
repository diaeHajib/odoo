from odoo import api, fields, models


class NyxDemoItem(models.Model):
    _name = "nyx.demo.item"
    _description = "Nyx Demo Item"
    _order = "create_date desc"

    name = fields.Char(string="Title", required=True)
    note = fields.Text(string="Notes")
    qty = fields.Integer(default=1)
    state = fields.Selection(
        [("draft", "Draft"), ("done", "Done")],
        default="draft",
        required=True,
    )
    owner_id = fields.Many2one("res.users", string="Owner",
                               default=lambda self: self.env.user)

    def action_mark_done(self):
        for rec in self:
            rec.state = "done"

    @api.depends("name", "state")
    def _compute_display_name(self):
        for rec in self:
            rec.display_name = f"[{rec.state.upper()}] {rec.name}"
