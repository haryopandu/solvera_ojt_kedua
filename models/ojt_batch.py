from datetime import datetime
from statistics import mean

from odoo import _, api, fields, models
from odoo.exceptions import ValidationError
from odoo.tools.misc import format_datetime


class OJTBatch(models.Model):
    _name = 'ojt.batch'
    _description = 'OJT Batch'
    _inherit = ['mail.thread', 'mail.activity.mixin']
    _order = 'start_date desc, name'

    name = fields.Char(required=True, index=True, tracking=True)
    code = fields.Char(required=True, copy=False, tracking=True, index=True)
    job_id = fields.Many2one(
        'hr.job',
        string='Job',
        tracking=True,
        check_company=True,
    )
    description = fields.Html()
    department_id = fields.Many2one(
        'hr.department',
        string='Department',
        tracking=True,
        check_company=True,
    )
    mentor_ids = fields.Many2many(
        'res.partner',
        'ojt_batch_mentor_rel',
        'batch_id',
        'partner_id',
        string='Mentors',
    )
    start_date = fields.Date(required=True, tracking=True)
    end_date = fields.Date(required=True, tracking=True)
    mode = fields.Selection(
        selection=[
            ('online', 'Online'),
            ('offline', 'Offline'),
            ('hybrid', 'Hybrid'),
        ],
        default='online',
        required=True,
        tracking=True,
    )
    capacity = fields.Integer()
    participant_ids = fields.One2many('ojt.participant', 'batch_id')
    event_link_ids = fields.One2many('ojt.event.link', 'batch_id')
    course_ids = fields.Many2many(
        'slide.channel',
        'ojt_batch_channel_rel',
        'batch_id',
        'channel_id',
        string='Courses',
    )
    survey_id = fields.Many2one(
        'survey.survey',
        string='Evaluation Survey',
        check_company=True,
    )
    state = fields.Selection(
        selection=[
            ('draft', 'Draft'),
            ('recruit', 'Recruitment'),
            ('ongoing', 'Ongoing'),
            ('done', 'Done'),
            ('cancel', 'Cancelled'),
        ],
        default='draft',
        tracking=True,
    )
    certificate_rule_attendance = fields.Float(default=80.0)
    certificate_rule_score = fields.Float(default=70.0)
    progress_ratio = fields.Float(
        compute='_compute_progress_ratio',
        store=True,
        readonly=True,
    )
    next_event_display = fields.Char(
        compute='_compute_next_event_display',
        string='Next Agenda',
    )
    color = fields.Integer()
    company_id = fields.Many2one(
        'res.company',
        required=True,
        default=lambda self: self.env.company,
        index=True,
        check_company=True,
    )
    active = fields.Boolean(default=True)

    _sql_constraints = [
        ('ojt_batch_code_unique', 'unique(code)', 'The batch code must be unique.'),
    ]

    _locked_fields_on_progress = {
        'name',
        'code',
        'job_id',
        'description',
        'department_id',
        'mentor_ids',
        'start_date',
        'end_date',
        'mode',
        'capacity',
        'course_ids',
        'survey_id',
        'certificate_rule_attendance',
        'certificate_rule_score',
        'company_id',
    }

    def _get_sequence(self):
        """Return the configured batch sequence or None if missing."""
        try:
            return self.env.ref('solvera_ojt_kedua.seq_ojt_batch_code')
        except ValueError:
            return None

    @api.depends('participant_ids', 'participant_ids.progress_ratio')
    def _compute_progress_ratio(self):
        """Compute the average progress based on linked participants."""
        for batch in self:
            participants = batch.participant_ids
            if not participants:
                batch.progress_ratio = 0.0
                continue
            try:
                progress_values = participants.mapped('progress_ratio')
            except AttributeError:
                batch.progress_ratio = 0.0
                continue
            values = [value for value in progress_values if isinstance(value, (int, float))]
            batch.progress_ratio = mean(values) if values else 0.0

    def _compute_next_event_display(self):
        """Compose a textual description of the nearest scheduled agenda."""
        for batch in self:
            next_info = ''
            nearest_datetime = None
            for link in batch.event_link_ids:
                start_dt = self._extract_event_start_datetime(link)
                if not start_dt:
                    continue
                if not nearest_datetime or start_dt < nearest_datetime:
                    nearest_datetime = start_dt
                    name = getattr(link, 'name', False) or getattr(link, 'display_name', False)
                    next_info = name or ''
                    if nearest_datetime:
                        formatted = format_datetime(self.env, nearest_datetime, tz=self.env.user.tz)
                        next_info = f"{next_info} ({formatted})" if next_info else formatted
            batch.next_event_display = next_info

    @api.model_create_multi
    def create(self, vals_list):
        sequence = self._get_sequence()
        for vals in vals_list:
            code = vals.get('code')
            if code:
                continue
            if sequence:
                vals['code'] = sequence.next_by_id()
                continue
            next_code = self.env['ir.sequence'].next_by_code('ojt.batch')
            vals['code'] = next_code or _('New')
        records = super().create(vals_list)
        records._auto_update_state()
        return records

    def write(self, vals):
        self._ensure_dates(vals)
        if vals:
            self._validate_locked_fields(vals)
        res = super().write(vals)
        if not self.env.context.get('skip_state_update'):
            self._auto_update_state()
        return res

    def _validate_locked_fields(self, vals):
        """Disallow configuration changes once the batch is underway."""
        locked = self._locked_fields_on_progress & set(vals.keys())
        if not locked:
            return
        modifiable = self.filtered(lambda batch: batch.state not in ('ongoing', 'done'))
        if modifiable == self:
            return
        raise ValidationError(
            _(
                'The following fields cannot be modified when the batch is ongoing or completed: %s'
            )
            % ', '.join(sorted(locked))
        )

    def _ensure_dates(self, vals):
        """Validate date order pre-write when updates happen in bulk."""
        if 'start_date' not in vals and 'end_date' not in vals:
            return
        for batch in self:
            start_value = vals.get('start_date', batch.start_date)
            end_value = vals.get('end_date', batch.end_date)
            start = fields.Date.to_date(start_value) if start_value else None
            end = fields.Date.to_date(end_value) if end_value else None
            if start and end and start > end:
                raise ValidationError(_('The start date must be earlier than or equal to the end date.'))

    @api.constrains('start_date', 'end_date')
    def _check_dates(self):
        for batch in self:
            if batch.start_date and batch.end_date and batch.start_date > batch.end_date:
                raise ValidationError(_('The start date must be earlier than or equal to the end date.'))

    def _auto_update_state(self):
        """Automatically move batches through their lifecycle based on activity."""
        if not self:
            return
        today = fields.Date.context_today(self)
        now = fields.Datetime.now()
        for batch in self.with_context(skip_state_update=True):
            if batch.state in ('cancel', 'done'):
                continue
            new_state = False
            if batch.state == 'draft' and batch._has_active_recruitment():
                new_state = 'recruit'
            if batch.state in ('draft', 'recruit') and batch._has_started(today, now):
                new_state = 'ongoing'
            if batch.state == 'ongoing' and batch._is_completed(today, now):
                new_state = 'done'
            if new_state and new_state != batch.state:
                batch.with_context(skip_state_update=True).write({'state': new_state})

    def _has_active_recruitment(self):
        """Return whether the batch recruitment is considered opened."""
        self.ensure_one()
        if not self.job_id:
            return False
        applicant_model = self.env['hr.applicant']
        if 'ojt_batch_id' in applicant_model._fields:
            return bool(applicant_model.search_count([('ojt_batch_id', '=', self.id), ('active', '=', True)]))
        return True

    def _has_started(self, today, now):
        """Check if the batch should move to the ongoing stage."""
        self.ensure_one()
        if self.start_date and self.start_date <= today:
            return True
        for link in self.event_link_ids:
            start_dt = self._extract_event_start_datetime(link)
            if start_dt and start_dt <= now:
                return True
        return False

    def _is_completed(self, today, now):
        """Check if the batch can be considered completed."""
        self.ensure_one()
        if self.end_date and self.end_date <= today:
            return True
        for link in self.event_link_ids:
            end_dt = self._extract_event_end_datetime(link)
            if end_dt and end_dt > now:
                return False
        return bool(self.event_link_ids)

    @staticmethod
    def _extract_event_start_datetime(event_link):
        for field_name in ('start_datetime', 'start_date', 'scheduled_datetime', 'schedule_date'):
            if hasattr(event_link, field_name):
                value = getattr(event_link, field_name)
                if value:
                    if isinstance(value, datetime):
                        return value
                    try:
                        return fields.Datetime.to_datetime(value)
                    except (TypeError, ValueError):
                        return None
        return None

    @staticmethod
    def _extract_event_end_datetime(event_link):
        for field_name in ('end_datetime', 'end_date', 'deadline', 'schedule_deadline'):
            if hasattr(event_link, field_name):
                value = getattr(event_link, field_name)
                if value:
                    if isinstance(value, datetime):
                        return value
                    try:
                        return fields.Datetime.to_datetime(value)
                    except (TypeError, ValueError):
                        return None
        start_dt = OJTBatch._extract_event_start_datetime(event_link)
        return start_dt