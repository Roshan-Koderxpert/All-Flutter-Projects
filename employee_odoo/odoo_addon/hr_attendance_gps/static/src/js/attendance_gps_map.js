/** @odoo-module **/

import { registry } from "@web/core/registry";
import { Component, useEffect, useRef, xml } from "@odoo/owl";
import { standardFieldProps } from "@web/views/fields/standard_field_props";

const OSRM = "https://router.project-osrm.org/route/v1/driving/";
const MAX_WAYPOINTS = 25;
// Below this overall extent the trace is treated as "did not really move":
// snapping it to roads makes OSRM invent a long vehicle detour.
const MIN_SPAN_M_TO_SNAP = 75;
// Consecutive points closer than this are GPS jitter and are collapsed.
const JITTER_M = 5;
// A snapped route may not exceed this multiple of the raw trace length...
const MAX_INFLATION = 3.0;
// ...with this absolute allowance for short but genuine routes.
const MIN_ABS_ALLOWANCE_M = 400;

function haversineMeters(a, b) {
    const R = 6371000;
    const dLat = ((b[0] - a[0]) * Math.PI) / 180;
    const dLng = ((b[1] - a[1]) * Math.PI) / 180;
    const lat1 = (a[0] * Math.PI) / 180;
    const lat2 = (b[0] * Math.PI) / 180;
    const h =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
    return 2 * R * Math.asin(Math.sqrt(h));
}

function lineDistance(line) {
    let meters = 0;
    for (let i = 1; i < line.length; i++) {
        meters += haversineMeters(line[i - 1], line[i]);
    }
    return meters;
}

function spanMeters(line) {
    let minLat = line[0][0];
    let maxLat = line[0][0];
    let minLng = line[0][1];
    let maxLng = line[0][1];
    for (const p of line) {
        if (p[0] < minLat) minLat = p[0];
        if (p[0] > maxLat) maxLat = p[0];
        if (p[1] < minLng) minLng = p[1];
        if (p[1] > maxLng) maxLng = p[1];
    }
    return haversineMeters([minLat, minLng], [maxLat, maxLng]);
}

/**
 * Read-only field widget that draws the attendance GPS route on a Leaflet /
 * OpenStreetMap map, snapping the trace to roads via OSRM (same rules as the
 * mobile app). Bind it to the `gps_route_json` char field.
 *
 * Leaflet is bundled locally by this addon (static/lib/leaflet), so there is no
 * external CDN dependency, and the template is inline to avoid a separate
 * template-loading step.
 */
export class AttendanceGpsMapField extends Component {
    static props = { ...standardFieldProps };
    static template = xml`
        <div class="o_attendance_gps_map" style="width: 100%;">
            <div t-ref="map"
                style="height: 400px; width: 100%; border: 1px solid #dee2e6; border-radius: 8px; overflow: hidden; background: #e9ecef;"/>
        </div>`;

    setup() {
        this.mapRef = useRef("map");
        this._map = null;
        this._resizeObserver = null;
        useEffect(
            () => {
                this._renderMap();
                return () => this._destroy();
            },
            () => [this._routeJson]
        );
    }

    /** Leaflet renders blank if the container had no size at init. Keep
     *  recalculating until the layout settles. */
    _watchSize(map, el) {
        const refresh = () => {
            if (this._map) {
                this._map.invalidateSize();
            }
        };
        requestAnimationFrame(refresh);
        [100, 300, 800, 1500].forEach((ms) => setTimeout(refresh, ms));
        if (window.ResizeObserver) {
            this._resizeObserver = new ResizeObserver(refresh);
            this._resizeObserver.observe(el);
        }
    }

    get _routeJson() {
        return this.props.record.data[this.props.name] || "";
    }

    get _points() {
        try {
            const arr = JSON.parse(this._routeJson || "[]");
            return Array.isArray(arr)
                ? arr.filter((p) => p && p.lat != null && p.lng != null)
                : [];
        } catch (e) {
            return [];
        }
    }

    _destroy() {
        if (this._resizeObserver) {
            this._resizeObserver.disconnect();
            this._resizeObserver = null;
        }
        if (this._map) {
            this._map.remove();
            this._map = null;
        }
    }

    /** Fit the view, handling a degenerate (single-spot) bounding box. */
    _fit(map, line) {
        const L = window.L;
        try {
            if (!line || line.length === 0) {
                return;
            }
            if (line.length === 1) {
                map.setView(line[0], 18);
                return;
            }
            const bounds = L.latLngBounds(line);
            if (!bounds.isValid()) {
                map.setView(line[0], 18);
                return;
            }
            const ne = bounds.getNorthEast();
            const sw = bounds.getSouthWest();
            if (
                Math.abs(ne.lat - sw.lat) < 1e-6 &&
                Math.abs(ne.lng - sw.lng) < 1e-6
            ) {
                map.setView(bounds.getCenter(), 18);
            } else {
                map.fitBounds(bounds, { padding: [30, 30], maxZoom: 18 });
            }
        } catch (e) {
            map.setView(line[0], 18);
        }
    }

    async _renderMap() {
        const L = window.L;
        const el = this.mapRef.el;
        if (!el) {
            return;
        }
        this._destroy();
        el.innerHTML = "";

        if (!L) {
            console.error(
                "[hr_attendance_gps] Leaflet (window.L) is unavailable — the bundled " +
                    "library did not load. Restart Odoo, upgrade the module, hard-refresh."
            );
            el.innerHTML =
                "<div class='alert alert-warning m-0'>Map library (Leaflet) not loaded. " +
                "Restart Odoo, upgrade the module, then hard-refresh (Ctrl+Shift+R).</div>";
            return;
        }
        const pts = this._points;
        console.log(
            `[hr_attendance_gps] Leaflet OK — ${pts.length} GPS point(s) to draw`
        );
        if (pts.length === 0) {
            el.innerHTML =
                "<div class='alert alert-info m-0'>No route recorded for this attendance.</div>";
            return;
        }

        try {
            const latlngs = pts.map((p) => [p.lat, p.lng]);
            const map = L.map(el, { scrollWheelZoom: true });
            this._map = map;
            this._watchSize(map, el);

            L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
                maxZoom: 19,
                attribution: "© OpenStreetMap contributors",
            })
                .on("tileerror", () => {
                    console.warn(
                        "[hr_attendance_gps] Map tiles failed to load — check the browser " +
                            "can reach tile.openstreetmap.org (CSP / network / proxy)."
                    );
                })
                .addTo(map);

            // Draw the raw trace immediately so something is visible before the
            // (async) road-snapping resolves.
            this._fit(map, latlngs);

            const line = await this._buildLine(latlngs, pts);
            if (!this._map) {
                return; // destroyed while awaiting
            }
            const drawn = line && line.length >= 2 ? line : latlngs;

            L.polyline(drawn, { color: "#1F5786", weight: 4 }).addTo(map);
            this._fit(map, drawn);

            L.circleMarker(latlngs[0], {
                radius: 8,
                color: "#ffffff",
                weight: 2,
                fillColor: "#2e7d32",
                fillOpacity: 1,
            })
                .addTo(map)
                .bindTooltip("Check in");
            if (latlngs.length > 1) {
                L.circleMarker(latlngs[latlngs.length - 1], {
                    radius: 8,
                    color: "#ffffff",
                    weight: 2,
                    fillColor: "#c62828",
                    fillOpacity: 1,
                })
                    .addTo(map)
                    .bindTooltip("Check out");
            }
            console.log(
                `[hr_attendance_gps] route drawn with ${drawn.length} line point(s)`
            );
        } catch (e) {
            console.error("[hr_attendance_gps] render failed", e);
            el.innerHTML =
                "<div class='alert alert-danger m-0'>Could not render the route map: " +
                (e && e.message ? e.message : e) +
                "</div>";
        }
    }

    /** Raw trace, upgraded to a road-snapped line only when that is sensible. */
    async _buildLine(latlngs, pts) {
        if (latlngs.length < 2) {
            return latlngs;
        }
        // Barely moved -> snapping would invent a road detour.
        if (spanMeters(latlngs) < MIN_SPAN_M_TO_SNAP) {
            return latlngs;
        }
        try {
            const snapped = await this._snapToRoads(pts);
            if (!snapped || snapped.length < 2) {
                return latlngs;
            }
            // Reject routing artefacts (one-way loops, detours around buildings).
            const allowed = Math.max(
                MIN_ABS_ALLOWANCE_M,
                lineDistance(latlngs) * MAX_INFLATION
            );
            if (lineDistance(snapped) > allowed) {
                return latlngs;
            }
            return snapped;
        } catch (e) {
            return latlngs;
        }
    }

    async _snapToRoads(pts) {
        // Collapse GPS jitter before routing.
        const cleaned = [pts[0]];
        for (let i = 1; i < pts.length; i++) {
            const last = cleaned[cleaned.length - 1];
            const gap = haversineMeters(
                [last.lat, last.lng],
                [pts[i].lat, pts[i].lng]
            );
            if (gap >= JITTER_M) {
                cleaned.push(pts[i]);
            }
        }
        if (cleaned.length < 2) {
            return null;
        }

        let waypoints = cleaned;
        if (cleaned.length > MAX_WAYPOINTS) {
            waypoints = [];
            const step = (cleaned.length - 1) / (MAX_WAYPOINTS - 1);
            for (let i = 0; i < MAX_WAYPOINTS; i++) {
                waypoints.push(cleaned[Math.round(i * step)]);
            }
        }
        const coords = waypoints.map((p) => `${p.lng},${p.lat}`).join(";");
        const resp = await fetch(
            `${OSRM}${coords}?geometries=geojson&overview=full`
        );
        if (!resp.ok) {
            return null;
        }
        const data = await resp.json();
        if (data.code !== "Ok" || !data.routes || !data.routes.length) {
            return null;
        }
        // GeoJSON coordinates are [lng, lat].
        return data.routes[0].geometry.coordinates.map((c) => [c[1], c[0]]);
    }
}

registry.category("fields").add("attendance_gps_map", {
    component: AttendanceGpsMapField,
    supportedTypes: ["char", "text"],
});
