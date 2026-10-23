# -*- coding: utf-8 -*-
import json
import math

from odoo import _, api, fields, models
from odoo.exceptions import AccessError, UserError

ATTENDANCE_MANAGER_GROUP = "hr_attendance.group_hr_attendance_manager"


class HrAttendance(models.Model):
    _inherit = "hr.attendance"

    gps_point_ids = fields.One2many(
        "hr.attendance.gps.point",
        "attendance_id",
        string="GPS Points",
    )
    gps_point_count = fields.Integer(
        string="GPS Point Count",
        compute="_compute_gps_stats",
    )
    gps_distance_km = fields.Float(
        string="Route Distance (km)",
        compute="_compute_gps_stats",
        digits=(10, 3),
    )
    gps_route_json = fields.Char(
        string="GPS Route JSON",
        compute="_compute_gps_route_json",
        help="Ordered [{lat, lng}] points, consumed by the backend map widget.",
    )

    @api.depends(
        "gps_point_ids",
        "gps_point_ids.latitude",
        "gps_point_ids.longitude",
    )
    def _compute_gps_stats(self):
        for attendance in self:
            points = attendance.gps_point_ids.sorted(
                key=lambda p: (
                    p.sequence,
                    p.point_time or fields.Datetime.now(),
                    p.id,
                )
            )
            attendance.gps_point_count = len(points)
            distance = 0.0
            previous = None
            for point in points:
                if previous is not None:
                    distance += self._haversine_km(
                        previous.latitude,
                        previous.longitude,
                        point.latitude,
                        point.longitude,
                    )
                previous = point
            attendance.gps_distance_km = distance

    @api.depends(
        "gps_point_ids",
        "gps_point_ids.latitude",
        "gps_point_ids.longitude",
    )
    def _compute_gps_route_json(self):
        for attendance in self:
            points = attendance.gps_point_ids.sorted(
                key=lambda p: (
                    p.sequence,
                    p.point_time or fields.Datetime.now(),
                    p.id,
                )
            )
            data = [
                {"lat": p.latitude, "lng": p.longitude}
                for p in points
                if p.latitude and p.longitude
            ]
            attendance.gps_route_json = json.dumps(data)

    @staticmethod
    def _haversine_km(lat1, lon1, lat2, lon2):
        radius = 6371.0
        d_lat = math.radians(lat2 - lat1)
        d_lon = math.radians(lon2 - lon1)
        a = (
            math.sin(d_lat / 2) ** 2
            + math.cos(math.radians(lat1))
            * math.cos(math.radians(lat2))
            * math.sin(d_lon / 2) ** 2
        )
        return radius * 2 * math.asin(math.sqrt(a))

    @api.model
    def record_gps_points(self, attendance_id, points):
        """Batch-create GPS points for an attendance record.

        Called from the mobile app via JSON-RPC. ``points`` is a list of dicts
        with keys: latitude, longitude, accuracy, altitude, speed, point_time
        (UTC "YYYY-MM-DD HH:MM:SS"), sequence. Returns the number of points
        stored.
        """
        attendance = self.browse(int(attendance_id)).exists()
        if not attendance:
            raise UserError(_("Attendance %s was not found.") % attendance_id)

        is_manager = self.env.user.has_group(ATTENDANCE_MANAGER_GROUP)
        if not is_manager and attendance.employee_id.user_id.id != self.env.uid:
            raise AccessError(
                _("You cannot add GPS points to another employee's attendance.")
            )

        gps_point = self.env["hr.attendance.gps.point"].sudo()
        values = []
        for point in points or []:
            latitude = point.get("latitude")
            longitude = point.get("longitude")
            if latitude is None or longitude is None:
                continue
            values.append(
                {
                    "attendance_id": attendance.id,
                    "latitude": latitude,
                    "longitude": longitude,
                    "accuracy": point.get("accuracy") or 0.0,
                    "altitude": point.get("altitude") or 0.0,
                    "speed": point.get("speed") or 0.0,
                    "point_time": point.get("point_time") or False,
                    "sequence": point.get("sequence") or 0,
                }
            )
        if not values:
            return 0
        gps_point.create(values)
        return len(values)
