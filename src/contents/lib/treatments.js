// Single source of truth for treatment types, colors, and payload building.
// Eliminates the duplicate hard-coded arrays and color maps that previously
// lived separately in FullRepresentation.qml.

// ---- Helpers -----------------------------------------------------------

function pad2(n) { return n < 10 ? "0" + n : "" + n; }

function pad3(n) { return n < 10 ? "00" + n : n < 100 ? "0" + n : "" + n; }

// Generate a v4 UUID (no external dependency needed).
function uuidv4() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
        var r = Math.random() * 16 | 0;
        return (c === "x" ? r : (r & 0x3 | 0x8)).toString(16);
    });
}

// Format a Date as the xDrip sysTime string, e.g.
// "2026-07-09T12:31:02.666-0400" or "...+0530".
function formatSysTime(d) {
    var y = d.getFullYear();
    var mo = pad2(d.getMonth() + 1);
    var day = pad2(d.getDate());
    var h = pad2(d.getHours());
    var mi = pad2(d.getMinutes());
    var s = pad2(d.getSeconds());
    var ms = pad3(d.getMilliseconds());
    var off = -d.getTimezoneOffset();
    var oh = Math.abs(Math.floor(off / 60));
    var om = Math.abs(off % 60);
    var sign = off >= 0 ? "+" : "-";
    return y + "-" + mo + "-" + day + "T" + h + ":" + mi + ":" + s + "." + ms
        + sign + pad2(oh) + pad2(om);
}

// ---- Type descriptors --------------------------------------------------

// The three treatment kinds exposed by the widget UI.
var TYPES = [
    {
        key: "carbs",
        label: "Carbs",
        accent: "#f97316"
    },
    {
        key: "humalog",
        label: "Humalog",
        accent: "#ec4899",
        insulin: "Humalog"
    },
    {
        key: "tresiba",
        label: "Tresiba",
        accent: "#3b82f6",
        insulin: "tresiba"
    }
];

// Look up a type descriptor by key. Returns the carbs descriptor on miss so
// the UI always has something sensible to fall back to.
function typeByKey(key) {
    for (var i = 0; i < TYPES.length; i++) {
        if (TYPES[i].key === key) return TYPES[i];
    }
    return TYPES[0];
}

// Attribution value recorded for every uploaded treatment. This is the
// client identity xDrip peers see in `enteredBy`.
var ENTERED_BY = "kde-widget";

// Build the POST body for a new treatment in xDrip-compatible format.
// `dateObj` is a JavaScript Date object set to the desired treatment time.
function buildPayload(typeKey, value, dateObj) {
    var t = typeByKey(typeKey);
    var isCarbs = t.key === "carbs";
    var ts = dateObj.getTime();
    // created_at truncates milliseconds to match xDrip convention.
    var wholeSec = new Date(dateObj);
    wholeSec.setMilliseconds(0);

    // Emit fields in the same order xDrip uploads them: the active type
    // field (carbs or insulin) sits right after uuid, and the inactive
    // field (null) is appended last.
    var payload = {
        timestamp: ts,
        eventType: "<none>",
        enteredBy: ENTERED_BY,
        uuid: uuidv4()
    };
    if (isCarbs) {
        payload.carbs = value;
    } else {
        payload.insulin = value;
    }
    payload.insulinInjections = isCarbs
        ? "[]"
        : JSON.stringify([{ insulin: t.insulin, units: value }]);
    payload.created_at = wholeSec.toISOString();
    payload.sysTime = formatSysTime(dateObj);
    payload.utcOffset = 0;
    if (isCarbs) {
        payload.insulin = null;
    } else {
        payload.carbs = null;
    }
    return payload;
}

// Decide on a display color for an existing treatment record. Order matters:
// mixed carbs+insulin gets purple; carbs-only orange; Humalog pink; other
// insulin blue. Handles both xDrip's JSON-string insulinInjections and the
// inline-array form.
function colorFor(t) {
    if (t.carbs) {
        if (t.insulin) return "#8e44ad";
        return "#f97316";
    }
    // Normalize insulinInjections: parse JSON string if needed.
    var injections = t.insulinInjections;
    if (typeof injections === "string") {
        try {
            injections = JSON.parse(injections);
        } catch (e) {
            injections = null;
        }
    }
    if (Array.isArray(injections) && injections.length > 0) {
        if (injections[0].insulin === "Humalog") {
            return "#ec4899";
        }
    }
    if (t.insulin) return "#3b82f6";
    return "#95a5a6";
}

// Short human label for an existing treatment: "5g 2.1u" / "15g" / "notes".
function labelFor(t) {
    var parts = [];
    if (t.carbs) parts.push(Math.round(t.carbs) + "g");
    if (t.insulin) parts.push(parseFloat(t.insulin).toFixed(1) + "u");
    if (parts.length === 0 && t.notes) parts.push(t.notes);
    return parts.join(" ");
}

// Extract a ms-since-epoch timestamp from a treatment record, tolerating the
// `timestamp` field (number, xDrip), `date` (number), and `created_at` (ISO).
function timestampFor(t) {
    if (t.timestamp) return t.timestamp;
    if (t.date) return t.date;
    if (t.created_at) return new Date(t.created_at).getTime();
    return 0;
}

// Map a treatment timestamp onto a fractional entry index.
//
// `chartTimestamps` is the array of timestamps (ms-since-epoch) for each
// entry the chart currently shows. The chart plots entries uniformly across
// the panel width by *array position*, so for a treatment's dot to align with
// the underlying glucose reading at that moment, we need its fractional
// array-index, not a direct timestamps-to-pixel mapping (which incorrectly
// assumes the chart's right edge represents "now").
//
// - Returns 0 if the timestamp is on/before the first entry.
// - Returns a value > lastEntryIndex if the timestamp is past the last
//   reading (extrapolated using the spacing of the last two entries, which
//   gives a "fresh treatment" a sensible position near the right edge
//   rather than dumping it at the far left).
// - Returns 0 if `chartTimestamps` has fewer than 2 entries.
function timestampToFractionalIndex(chartTimestamps, ts) {
    if (!chartTimestamps || chartTimestamps.length < 2) return 0;
    var n = chartTimestamps.length;
    if (chartTimestamps.length === 1) return 0;
    if (ts <= chartTimestamps[0]) return 0;
    // Binary search for the rightmost index where ct[i] <= ts.
    var lo = 0, hi = n - 1;
    while (lo < hi - 1) {
        var mid = (lo + hi) >> 1;
        if (chartTimestamps[mid] <= ts) lo = mid; else hi = mid;
    }
    // Past the last reading: extrapolate from the spacing of the last two
    // entries. Captures "a treatment logged 30s after the last reading is
    // rendered just to the right of that reading".
    if (ts >= chartTimestamps[hi]) {
        var lastGap = chartTimestamps[hi] - chartTimestamps[lo];
        if (lastGap <= 0) return n - 1;
        return hi + (ts - chartTimestamps[hi]) / lastGap;
    }
    // Between two entries: linear interpolation in time.
    var span = chartTimestamps[hi] - chartTimestamps[lo];
    if (span <= 0) return lo;
    return lo + (ts - chartTimestamps[lo]) / span;
}
