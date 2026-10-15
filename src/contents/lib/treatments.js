// Single source of truth for treatment types, colors, and payload building.
// Matches the JugglucoNG Nightscout treatment format so the desktop widget
// and mobile app work together seamlessly.

// ---- Helpers -----------------------------------------------------------

// Attribution values recorded for uploaded treatments.
var ENTERED_BY = "kde-widget";
var APP = "kde-widget";
var ID_PREFIX = "kde-w-";

// Generate a treatment identifier:
// "kde-w-<hex random 3 chars>-<epoch ms hex>".
function generateTreatmentId(dateObj) {
    var ts = dateObj.getTime();
    var hexRand = ("000" + Math.floor(Math.random() * 0x1000).toString(16)).slice(-3);
    return ID_PREFIX + hexRand + "-" + ts.toString(16);
}

// Default carb absorption duration in minutes from JugglucoNG formula:
// 60 + 2 * carbs + 1.5 * protein + 2.5 * fat, clamped to [30, 360].
function defaultAbsorptionMinutes(carbs) {
    var c = parseFloat(carbs) || 0;
    return Math.min(360, Math.max(30, Math.round(60 + 2 * c)));
}

// ---- Type descriptors --------------------------------------------------

// Default treatment kinds exposed by the widget UI.
var TYPES = [
    {
        key: "carbs",
        label: "Carbs",
        accent: "#f97316"
    },
    {
        key: "admelog",
        label: "Admelog",
        accent: "#ec4899",
        insulin: "Admelog",
        isBasal: false,
        notes: "Rapid-Acting",
        onsetMinutes: 21,
        durationMinutes: 330
    },
    {
        key: "tresiba",
        label: "Tresiba",
        accent: "#3b82f6",
        insulin: "Tresiba",
        isBasal: true,
        notes: "Long-Acting",
        onsetMinutes: 0,
        durationMinutes: 2520
    }
];

// Return available types taking custom names and basal button visibility into account.
function getTypes(rapidName, basalName, showBasal) {
    var rName = (rapidName && rapidName.trim()) ? rapidName.trim() : "Admelog";
    var bName = (basalName && basalName.trim()) ? basalName.trim() : "Tresiba";
    var list = [
        {
            key: "carbs",
            label: "Carbs",
            accent: "#f97316"
        },
        {
            key: "admelog",
            label: rName,
            accent: "#ec4899",
            insulin: rName,
            isBasal: false,
            notes: "Rapid-Acting",
            onsetMinutes: 21,
            durationMinutes: 330
        }
    ];
    if (showBasal !== false) {
        list.push({
            key: "tresiba",
            label: bName,
            accent: "#3b82f6",
            insulin: bName,
            isBasal: true,
            notes: "Long-Acting",
            onsetMinutes: 0,
            durationMinutes: 2520
        });
    }
    return list;
}

// Look up a type descriptor by key. Maps legacy "humalog" and "rapid" keys to "admelog",
// and "basal" to "tresiba". Returns the carbs descriptor on miss so the UI always has something sensible.
function typeByKey(key, rapidName, basalName) {
    if (key === "humalog" || key === "rapid") key = "admelog";
    if (key === "basal") key = "tresiba";
    var rName = (rapidName && rapidName.trim()) ? rapidName.trim() : "Admelog";
    var bName = (basalName && basalName.trim()) ? basalName.trim() : "Tresiba";

    if (key === "admelog") {
        return {
            key: "admelog",
            label: rName,
            accent: "#ec4899",
            insulin: rName,
            isBasal: false,
            notes: "Rapid-Acting",
            onsetMinutes: 21,
            durationMinutes: 330
        };
    }
    if (key === "tresiba") {
        return {
            key: "tresiba",
            label: bName,
            accent: "#3b82f6",
            insulin: bName,
            isBasal: true,
            notes: "Long-Acting",
            onsetMinutes: 0,
            durationMinutes: 2520
        };
    }
    return TYPES[0];
}

// Build the POST body for a new treatment in JugglucoNG-compatible format.
// `dateObj` is a JavaScript Date object set to the desired treatment time.
function buildPayload(typeKey, value, dateObj, rapidName, basalName) {
    var t = typeByKey(typeKey, rapidName, basalName);
    var isCarbs = t.key === "carbs";
    var ts = dateObj.getTime();
    var id = generateTreatmentId(dateObj);
    var isoTime = dateObj.toISOString();

    var payload = {
        _id: id,
        date: ts,
        created_at: isoTime,
        utcOffset: 0,
        isValid: true,
        app: APP,
        enteredBy: ENTERED_BY,
        type: isCarbs ? "carbs" : "insulin",
        journalTitle: isCarbs ? "Food" : t.insulin,
        journalSource: "manual",
        updated_at: new Date().toISOString()
    };

    if (isCarbs) {
        var absMin = defaultAbsorptionMinutes(value);
        var durMs = absMin * 60000;
        payload.eventType = value < 12 ? "Carb Correction" : "Meal Bolus";
        payload.carbs = value;
        payload.food = "Food";
        payload.duration = durMs;
        payload.durationInMilliseconds = durMs;
        payload.absorptionTime = absMin;
        payload.identifier = id;
        payload.insulin = null;
    } else {
        payload.eventType = "Correction Bolus";
        payload.insulin = value;
        payload.isBasalInsulin = !!t.isBasal;
        payload.insulinType = t.insulin;
        payload.notes = t.notes;
        payload.insulinOnsetMinutes = t.onsetMinutes;
        payload.insulinDurationMinutes = t.durationMinutes;
        payload.identifier = id;
        payload.carbs = null;
    }

    return payload;
}

// Helper to decide if an insulin record represents rapid-acting insulin.
// Recognizes JugglucoNG (isBasalInsulin: false, notes "Rapid-Acting", insulinType "Admelog"),
// legacy Humalog records (insulinInjections with Humalog), configured custom rapid name,
// and common rapid insulin names.
function isRapidInsulin(t, rapidName) {
    if (t.isBasalInsulin === true) return false;
    if (t.isBasalInsulin === false) return true;

    // Check insulinType and journalTitle
    var typeStr = (t.insulinType || t.journalTitle || "").toLowerCase();
    if (rapidName && rapidName.trim() && typeStr.indexOf(rapidName.trim().toLowerCase()) !== -1) {
        return true;
    }
    if (/admelog|humalog|lispro|novolog|novorapid|aspart|fiasp|lyumjev|apidra|glulisine|afrezza/.test(typeStr)) {
        return true;
    }

    // Check notes
    if (t.notes && /rapid/i.test(t.notes)) {
        return true;
    }

    // Check legacy insulinInjections
    var injections = t.insulinInjections;
    if (typeof injections === "string") {
        try {
            injections = JSON.parse(injections);
        } catch (e) {
            injections = null;
        }
    }
    if (Array.isArray(injections) && injections.length > 0 && injections[0] && injections[0].insulin) {
        var injName = String(injections[0].insulin).toLowerCase();
        if (rapidName && rapidName.trim() && injName.indexOf(rapidName.trim().toLowerCase()) !== -1) {
            return true;
        }
        if (/admelog|humalog|lispro|novolog|novorapid|aspart|fiasp|lyumjev|apidra|glulisine|afrezza/.test(injName)) {
            return true;
        }
    }

    return false;
}

// Decide on a display color for an existing treatment record. Order matters:
// mixed carbs+insulin gets purple; carbs-only orange; rapid-acting insulin pink;
// other insulin (e.g. Tresiba / basal) blue; fallback neutral gray.
function colorFor(t, rapidName) {
    if (t.carbs) {
        if (t.insulin) return "#8e44ad";
        return "#f97316";
    }
    if (isRapidInsulin(t, rapidName)) {
        return "#ec4899";
    }
    if (t.insulin) {
        return "#3b82f6";
    }
    return "#95a5a6";
}

// Short human label for an existing treatment: "5g 2.1u" / "15g" / "notes".
function labelFor(t) {
    var parts = [];
    if (t.carbs) parts.push(Math.round(t.carbs) + "g");
    if (t.insulin) {
        var num = parseFloat(t.insulin);
        if (!isNaN(num)) {
            var rounded = Math.round(num * 10) / 10;
            parts.push(rounded.toFixed(1) + "u");
        }
    }
    if (parts.length === 0 && t.notes) parts.push(t.notes);
    return parts.join(" ");
}

// Extract a ms-since-epoch timestamp from a treatment record, tolerating the
// `timestamp` field (number, xDrip), `date` (number, JugglucoNG), and `created_at` (ISO).
function timestampFor(t) {
    if (t.timestamp) return t.timestamp;
    if (t.date) return t.date;
    if (t.created_at) return new Date(t.created_at).getTime();
    return 0;
}

// Extract a unique identifier from a treatment record for deletion or selection.
// Tolerates `_id` (standard Nightscout/MongoDB), `identifier` (xDrip/JugglucoNG), or `id`.
function idFor(t) {
    if (!t) return "";
    return t._id || t.identifier || t.id || "";
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
