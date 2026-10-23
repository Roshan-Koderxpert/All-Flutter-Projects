# -*- coding: utf-8 -*-
from odoo import fields, models


class HrAttendanceGpsPoint(models.Model):
    _name = "hr.attendance.gps.point"
    _description = "Attendance GPS Point"
    _order = "attendance_id, sequence, point_time, id"
    _rec_name = "point_time"

    attendance_id = fields.Many2one(
        "hr.attendance",
        string="Attendance",
        required=True,
        ondelete="cascade",
        index=True,
    )
    employee_id = fields.Many2one(
        "hr.employee",
        string="Employee",
        related="attendance_id.employee_id",
        store=True,
        index=True,
    )
    latitude = fields.Float(string="Latitude", digits=(10, 7))
    longitude = fields.Float(string="Longitude", digits=(10, 7))
    accuracy = fields.Float(string="Accuracy (m)")
    altitude = fields.Float(string="Altitude (m)")
    speed = fields.Float(string="Speed (m/s)")
    point_time = fields.Datetime(string="Recorded At")
    sequence = fields.Integer(string="Sequence", default=0)
