// Formatting helpers shared across the widget UI and data layer.

// Pad a single number to two digits (0 -> "00", 5 -> "05", 12 -> "12").
function pad2(num) {
    return String(num).padStart(2, '0');
}

// Human "Xm ago" string for a timestamp (ms since epoch).
//
// Formatting rules:
//   < 1 minute  -> "0m ago"
//   < 1 hour    -> "Xm ago"
//   >= 1 hour   -> "Xh Ym ago"  (Y omitted when it's exactly on the hour)
//
// Returns "" if the timestamp is falsy (0/null/undefined).
// Future timestamps return "0m ago" rather than a negative string, since the
// only legitimate producer of these timestamps is the Nightscout API whose
// clock may drift slightly ahead of the local clock; a negative "ago" reads
// as a bug rather than a clock skew.
function timeAgo(timestamp) {
    if (!timestamp) return "";
    var diffMs = Date.now() - timestamp;
    if (diffMs < 0) diffMs = 0;
    var totalMin = Math.floor(diffMs / 60000);
    if (totalMin < 60) {
        return totalMin + "m ago";
    }
    var hours = Math.floor(totalMin / 60);
    var mins = totalMin % 60;
    if (mins === 0) {
        return hours + "h ago";
    }
    return hours + "h " + mins + "m ago";
}
