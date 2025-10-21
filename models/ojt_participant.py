
from odoo import api, fields, models


class OJTParticipant(models.Model):
    _name = 'ojt.participant'
    _description = 'OJT Participant'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'enrollment_date desc, name'

    name = fields.Char(required=True, tracking=True)
    batch_id = fields.Many2one(
        'ojt.batch',
        string='Batch',
        required=True,
        ondelete='cascade',
        tracking=True,
    )
    partner_id = fields.Many2one(
        'res.partner',
        string='Contact',
        required=True,
        tracking=True,
    )
    email = fields.Char(related='partner_id.email', string='Email', store=True, readonly=False)
    phone = fields.Char(related='partner_id.phone', string='Phone', store=True, readonly=False)
    enrollment_date = fields.Date(
        default=fields.Date.context_today,
        required=True,
        tracking=True,
    )
    progress_ratio = fields.Float(default=0.0, tracking=True)
    active = fields.Boolean(default=True)

    @api.onchange('partner_id')
    def _onchange_partner_id(self):
        """Default the participant name to the selected contact when missing."""
        for participant in self:
            if participant.partner_id and not participant.name:
                participant.name = participant.partner_id.name or participant.name