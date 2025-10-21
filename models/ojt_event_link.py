from odoo import api, fields, models


class OJTEventLink(models.Model):
    """Additional agenda items associated with an OJT batch."""

    _name = 'ojt.event.link'
    _description = 'OJT Event Link'
    _order = 'start_datetime, id'

    name = fields.Char(required=True)
    batch_id = fields.Many2one(
        'ojt.batch',
        string='Batch',
        required=True,
        ondelete='cascade',
    )
    event_id = fields.Many2one(
        'event.event',
        string='Event',
        ondelete='set null',
    )
    start_datetime = fields.Datetime(string='Start')
    end_datetime = fields.Datetime(string='End')
    location = fields.Char()
    description = fields.Text()
    external_url = fields.Char(string='External URL')

    @api.onchange('event_id')
    def _onchange_event_id(self):
        for record in self:
            if not record.event_id:
                continue
            if not record.name:
                record.name = record.event_id.name
            record.start_datetime = record.event_id.date_begin
            record.end_datetime = record.event_id.date_end
            if record.event_id.address_id:
                record.location = record.event_id.address_id.display_name

    @api.model_create_multi
    def create(self, vals_list):
        records = super().create(vals_list)
        records._sync_related_event()
        return records

    def write(self, vals):
        res = super().write(vals)
        if 'event_id' in vals:
            self._sync_related_event()
        return res

    def _sync_related_event(self):
        for record in self:
            if not record.event_id:
                continue
            if not record.name:
                record.name = record.event_id.name
            if record.event_id.date_begin:
                record.start_datetime = record.event_id.date_begin
            if record.event_id.date_end:
                record.end_datetime = record.event_id.date_end
            if record.event_id.address_id:
                record.location = record.event_id.address_id.display_name