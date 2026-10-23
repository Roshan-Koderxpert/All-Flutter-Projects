# Attendance GPS Route Tracking (`hr_attendance_gps`)

Odoo addon that stores the continuous GPS route captured by the Employee Hub
mobile app between attendance check-in and check-out, and shows it on a map
**inside the Odoo backend** (attendance form).

## What it adds
- **Model `hr.attendance.gps.point`** — one row per GPS ping: `attendance_id`,
  `employee_id` (related, stored), `latitude`, `longitude`, `accuracy`,
  `altitude`, `speed`, `point_time` (UTC), `sequence`.
- **`hr.attendance` fields** — `gps_point_ids`, `gps_point_count`,
  `gps_distance_km` (haversine), and `gps_route_json` (feeds the map widget).
- **RPC `record_gps_points(attendance_id, points)`** — batch-creates points
  (called by the app).
- **Backend map** — the attendance form shows a **Route Map** section: an
  embedded Leaflet/OpenStreetMap map that draws the route, snapped to roads via
  the public OSRM service (falls back to a straight line if OSRM is blocked).
- **Bundled Leaflet** — the map library ships **inside this addon**
  (`static/lib/leaflet`), so there is **no external CDN dependency**.
- **Security** — employees see/write only their own points; attendance
  managers (`hr_attendance.group_hr_attendance_manager`) see everything.

## Install / upgrade (read carefully)
1. Copy the **entire** `hr_attendance_gps` folder into your Odoo addons path —
   **including the `static/` folder** (the map + Leaflet live there). If you
   zip it, zip the whole folder.
2. **Restart the Odoo server** (not just the UI "Upgrade") — newly added asset
   files need a real restart:
   ```bash
   sudo systemctl restart odoo      # or restart your container / odoo-bin
   ```
3. In Odoo: **Apps → Update Apps List**, then install or **Upgrade** *Attendance
   GPS Route Tracking*.
4. **Hard-refresh** the browser: `Ctrl+Shift+R` (Win) / `Cmd+Shift+R` (Mac) so
   the new JS/CSS bundle is served.

Then open any `hr.attendance` that has GPS points → the **Route Map** section
draws the route. Managers also get **Attendances ▸ GPS Route Points**.

## Requirements for the map to draw
The map runs in the browser, so the browser (not the server) needs to reach:
- `https://*.tile.openstreetmap.org` — map tiles.
- `https://router.project-osrm.org` — road snapping (optional; without it the
  line is straight, still shown).

If your Odoo enforces a strict Content-Security-Policy that blocks these,
allow those hosts. Leaflet itself is local, so a blank map = tiles blocked.

## Troubleshooting
- **You see raw JSON text instead of a map** → the JS asset didn't load. Confirm
  `static/src/js/attendance_gps_map.js` and `static/lib/leaflet/` are on the
  server, restart Odoo, hard-refresh. In dev mode, use *Regenerate Assets
  Bundles*.
- **"Route Map" section missing** → the view didn't refresh; upgrade the module
  and hard-refresh.
- **Grey/blank map** → tiles blocked by CSP/network (see above).
- **Straight line instead of road-following** → OSRM unreachable (CSP/network),
  or too few points; it falls back to a straight line by design.
- Still stuck? Open the attendance, press **F12 → Console**, and check for a red
  error mentioning `attendance_gps_map`, `leaflet`, or `Content Security Policy`.

## Quick RPC test (Odoo shell)
```python
att = env['hr.attendance'].search([], limit=1)
env['hr.attendance'].record_gps_points(att.id, [
    {'latitude': 23.0225, 'longitude': 72.5714, 'point_time': '2026-07-22 09:00:00', 'sequence': 0},
    {'latitude': 23.0300, 'longitude': 72.5800, 'point_time': '2026-07-22 09:05:00', 'sequence': 1},
])
att.gps_point_count, att.gps_distance_km
```

## Compatibility
Targets Odoo 16 / 17 / 18. Views use `<tree>` (works across these). If the
attendance-form enhancement fails to install because your build renamed
`hr_attendance.hr_attendance_view_form`, remove the `view_hr_attendance_form_gps`
record from `views/hr_attendance_gps_views.xml` — the model, RPC and security are
independent of it.
