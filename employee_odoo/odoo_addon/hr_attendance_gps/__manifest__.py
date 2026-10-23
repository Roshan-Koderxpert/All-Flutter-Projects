# -*- coding: utf-8 -*-
{
    "name": "Attendance GPS Route Tracking",
    "version": "1.0.0",
    "summary": "Record the employee GPS route between attendance check-in and check-out.",
    "description": """
Attendance GPS Route Tracking
=============================

Stores a continuous GPS route (one row per location ping) for every
``hr.attendance`` record. The points are captured by the Employee Hub mobile
app between check-in and check-out and pushed in batches via the
``record_gps_points`` RPC.

Adds:
  * ``hr.attendance.gps.point`` model (attendance_id, employee_id, latitude,
    longitude, accuracy, altitude, speed, point_time, sequence).
  * ``hr.attendance.gps_point_ids`` one2many plus ``gps_point_count`` and
    ``gps_distance_km`` computed helpers.
  * A batch ``record_gps_points(attendance_id, points)`` method.
  * Security so employees only see their own points and attendance managers
    see all.
""",
    "author": "Koderxpert Technologies LLP",
    "website": "https://www.koderxpert.com",
    "category": "Human Resources/Attendances",
    "license": "LGPL-3",
    "depends": ["hr_attendance"],
    "data": [
        "security/ir.model.access.csv",
        "security/hr_attendance_gps_security.xml",
        "views/hr_attendance_gps_views.xml",
    ],
    "assets": {
        "web.assets_backend": [
            "hr_attendance_gps/static/lib/leaflet/leaflet.css",
            "hr_attendance_gps/static/lib/leaflet/leaflet.js",
            "hr_attendance_gps/static/src/js/attendance_gps_map.js",
        ],
    },
    "installable": True,
    "application": False,
}
