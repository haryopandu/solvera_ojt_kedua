from odoo import _, api, fields, models
from odoo.exceptions import UserError


class HrApplicant(models.Model):
    _inherit = 'hr.applicant'

    can_enroll_to_ojt = fields.Boolean(compute='_compute_can_enroll_to_ojt')

    @api.depends('stage_id')
    def _compute_can_enroll_to_ojt(self):
        """Toggle the OJT enrollment button when the applicant is accepted."""
        accepted_stage = self.env.ref(
            'solvera_ojt_kedua.hr_recruitment_stage_accepted',
            raise_if_not_found=False,
        )
        for applicant in self:
            applicant.can_enroll_to_ojt = bool(accepted_stage) and applicant.stage_id == accepted_stage

    def action_enroll_to_ojt(self):
        """Post a confirmation message when an accepted applicant is enrolled."""
        self.ensure_one()
        accepted_stage = self.env.ref(
            'solvera_ojt_kedua.hr_recruitment_stage_accepted',
            raise_if_not_found=False,
        )
        if not accepted_stage or self.stage_id != accepted_stage:
            raise UserError(_('Only applicants in the Accepted stage can be enrolled to OJT.'))
        self.message_post(body=_('Applicant enrolled to OJT.'))
        return True