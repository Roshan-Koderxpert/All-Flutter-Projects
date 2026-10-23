# Attendance Route Tracking — build & test guide

Records the employee's continuous GPS route from **check-in to check-out**,
stores it in Odoo, and draws it on an in-app OpenStreetMap in the attendance
detail screen.

## Update — road-following line + backend map
- **Road snapping (app + backend):** the drawn line now follows streets. The
  recorded points are downsampled to ≤25 waypoints and sent to the public
  **OSRM** directions service (`router.project-osrm.org`), which returns the
  road geometry. If OSRM is unreachable it falls back to a straight point-to-
  point line. OSRM's public server is rate-limited and uses a driving profile.
- **Backend map (Odoo):** the attendance form now shows an embedded
  **Leaflet/OpenStreetMap** map (Route Map section) drawing the same snapped
  route. Leaflet loads from a CDN (`unpkg.com`); if your Odoo server's browser
  blocks external CDNs via CSP, allow `unpkg.com` + `*.tile.openstreetmap.org`
  + `router.project-osrm.org`, or bundle Leaflet locally.
- The OWL widget targets Odoo 16/17/18. If it doesn't render on your version,
  tell me the exact version.

> **After these changes you MUST re-deploy the addon** (copy the updated folder
> to the server) **and upgrade the module** in Odoo (Apps ▸ *Attendance GPS
> Route Tracking* ▸ Upgrade) so the new `gps_route_json` field and the map
> assets load. The old `.zip` is stale — re-zip from the current folder.

## What was added

**Odoo addon** — `odoo_addon/hr_attendance_gps/`
- Model `hr.attendance.gps.point` + `hr.attendance` fields (`gps_point_ids`,
  `gps_point_count`, `gps_distance_km`) + batch RPC `record_gps_points` +
  security. See its own `README.md`.

**Flutter** (packages: `geolocator`, `flutter_foreground_task`, `flutter_map`,
`latlong2`)
| File | Role |
|---|---|
| `lib/data/models/attendance_gps_point.dart` | GPS point model (Odoo + buffer JSON) |
| `lib/data/repositories/attendance_gps_repository.dart` | `recordPoints` / `fetchPoints` (+ `AttendanceGpsUnavailable`) |
| `lib/data/local/route_buffer_store.dart` | Cross-isolate, crash-safe point buffer |
| `lib/data/services/location_tracking_service.dart` | Foreground service + sampling + flush-to-Odoo |
| `lib/modules/attendance/utils/route_tracking_consent.dart` | Consent flag + disclosure dialog |
| `lib/modules/attendance/widgets/attendance_route_map.dart` | Polyline map + stats + full-screen |
| `home_controller.dart`, `attendance_repository.dart` | Permission/consent, start/stop, real lat/lng on check-in/out |
| `attendance_detail_{controller,view}.dart` | ROUTE section |
| `attendance_summary_card.dart`, `settings_page.dart`, `auth_controller.dart` | "Tracking active" pill, Settings toggle, logout cleanup |
| `AndroidManifest.xml`, `build.gradle.kts`, `Info.plist`, `main.dart` | Permissions, foreground service, SDK floor |

## How it works
1. **Check in** → consent + location permission → capture point → Odoo check-in
   (now sends real lat/lng) → read the open `hr.attendance` id → start the
   foreground service tagged with that id.
2. The **service isolate** samples GPS every 30 s and appends to a persistent
   buffer (survives app kill). The **main isolate** flushes the buffer to Odoo
   (`record_gps_points`) every 60 s and again at check-out.
3. **Check out** → capture final point → stop service → final flush → Odoo
   check-out.
4. **Attendance detail** → `fetchPoints` → polyline + start/end markers +
   distance/duration/point count.

If the Odoo addon isn't installed, the app degrades gracefully:
single check-in/out coordinates still record; the ROUTE section is hidden.

## Deploy (required, server-side)
1. Copy `odoo_addon/hr_attendance_gps/` into your Odoo addons path.
2. Restart Odoo → **Apps ▸ Update Apps List** → install **Attendance GPS Route
   Tracking**.
3. Sanity check via Odoo shell (see the addon's `README.md`).

## Build & run the app
```bash
flutter pub get        # already resolves geolocator/flutter_map/etc.
flutter run            # use a PHYSICAL Android device (emulators fake GPS)
```

## Permissions the user is asked
- **Location** — grant **"Allow all the time"** for true background tracking
  (Android 11+ prompts for background separately; "While using" still works
  while the persistent notification is shown).
- **Notifications** (Android 13+) — for the ongoing "route tracking" notification.
- Route tracking only starts after the one-time **consent dialog**; it can be
  turned off in **Settings ▸ Security ▸ Attendance Route Tracking**.

## Test checklist
1. Fresh install → **Check In** → accept consent + grant location (Allow all the
   time). A persistent "Attendance route tracking" notification appears and the
   card shows a green **"Route tracking active"** pill.
2. Background the app / lock the phone, walk ~200 m for a few minutes.
3. **Check Out** → open the record from **Attendance history** → the **ROUTE**
   section shows your path as a blue line with green (start) / red (end) pins
   and distance/duration/points.
4. In Odoo: open the `hr.attendance` record → "GPS Route" section lists the
   points and total distance (or **Attendances ▸ GPS Route Points** as manager).
5. Kill the app mid-shift → reopen while still checked in → tracking resumes.
6. Airplane-mode a segment → reconnect → the buffered points upload at the next
   flush / at check-out.

## Known limitations / possible next steps
- **iOS background** is best-effort (needs "Always" + the `location` background
  mode already added); Android is the primary target.
- **OSM tiles** use the public `tile.openstreetmap.org` server — fine for low
  volume; switch to a keyed tile provider for scale.
- **Sampling** is a fixed 30 s / high-accuracy; expose as a setting if needed.
- Optionally wrap the home screen in `WithForegroundTask` so the back button
  minimizes (instead of closing) while tracking.
- Server-side de-dup of `(attendance, sequence)` is not enforced; a crash
  between upload and high-water bump could, in theory, duplicate a batch.
