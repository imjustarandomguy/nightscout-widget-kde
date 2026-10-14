const Charset = {
    UNICODE_1: 0,
    UNICODE_2: 1,
    EMOJI: 2
}

// Map string direction names (Nightscout API direction strings) to numeric indices.
const DIRECTION_MAP = {
    "NONE": 0,
    "DoubleUp": 1,
    "SingleUp": 2,
    "FortyFiveUp": 3,
    "Flat": 4,
    "FortyFiveDown": 5,
    "SingleDown": 6,
    "DoubleDown": 7,
    "NOT COMPUTABLE": 8,
    "RATE OUT OF RANGE": 9
};

const trendArrows = {
    0: ["", "⇈", "↑", "↗", "→", "↘", "↓", "⇊", "?", "↹"],
    1: ["", "⬆⬆", "⬆", "⬈", "➡", "⬊", "⬇", "⬇⬇", "?", "⬌"],
    2: ["", "⬆️⬆️", "⬆️", "↗️", "➡️", "↘️", "⬇️", "⬇️⬇️", "↔️", "🔄"],
}

function getTrendArrow(charset, trend) {
    var set = trendArrows[charset] || trendArrows[Charset.UNICODE_1];
    var idx = trend;
    if (typeof trend === "string" && DIRECTION_MAP.hasOwnProperty(trend)) {
        idx = DIRECTION_MAP[trend];
    }
    if (typeof idx === "number" && idx >= 0 && idx < set.length) {
        return set[idx];
    }
    return "?";
}

function getCharsetText(charset) {
    if (charset == Charset.UNICODE_1) {
        return "Unicode 1 (" + trendArrows[Charset.UNICODE_1][3] + ")";
    } else if (charset == Charset.UNICODE_2) {
        return "Unicode 2 (" + trendArrows[Charset.UNICODE_2][3] + ")";
    } else if (charset == Charset.EMOJI) {
        return "Emoji (" + trendArrows[Charset.EMOJI][3] + ")";
    }
    return "Unicode 1 (" + trendArrows[Charset.UNICODE_1][3] + ")";
}
