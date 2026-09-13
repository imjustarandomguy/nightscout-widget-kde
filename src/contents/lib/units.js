const Unit = {
    MG_DL: 0,
    MMOL_L: 1
}

// Conversion factor between mg/dL and mmol/L.
var MMOL_PER_MGDL = 1 / 18.018;

function getUnitAwareValue(mgPDl, unit) {
    // Input is always in mg/dL (raw sensor value).
    if (unit == Unit.MG_DL) {
        return Math.round(mgPDl);
    } else if (unit == Unit.MMOL_L) {
        return parseFloat((mgPDl * MMOL_PER_MGDL).toFixed(1));
    }
}

function convertValue(value, fromUnit, toUnit) {
    // Convert a value between units (handles API responses in either unit).
    if (fromUnit == toUnit) {
        // No conversion needed, just format.
        if (toUnit == Unit.MMOL_L) {
            return parseFloat(value.toFixed(1));
        }
        return Math.round(value);
    }
    // Convert via mg/dL
    var mgDl = fromUnit == Unit.MMOL_L ? value / MMOL_PER_MGDL : value;
    if (toUnit == Unit.MMOL_L) {
        return parseFloat((mgDl * MMOL_PER_MGDL).toFixed(1));
    }
    return Math.round(mgDl);
}

function parseUnit(text) {
    // Parse API response unit string to Unit constant.
    if (text && text.toLowerCase().indexOf("mmol") !== -1) {
        return Unit.MMOL_L;
    }
    return Unit.MG_DL;
}

// Round a chart bound to an integer. The bound is assumed to already be in the
// correct unit; this only enforces integer granularity for display.
function roundChartBound(value) {
    return Math.round(value);
}

// Convert a chart bound between units. Unlike convertValue we keep integers
// in mg/dL because chart bounds there are typically whole numbers.
function convertBound(value, fromUnit, toUnit) {
    if (fromUnit === toUnit) return value;
    if (fromUnit === Unit.MMOL_L && toUnit === Unit.MG_DL) {
        return Math.round(value / MMOL_PER_MGDL);
    }
    if (fromUnit === Unit.MG_DL && toUnit === Unit.MMOL_L) {
        return parseFloat((value * MMOL_PER_MGDL).toFixed(1));
    }
    return value;
}

function getGlucoseColor(value, unit) {
    // Thresholds in mmol/L: <3.9 red, <4.5 yellow, >10 yellow, >13.4 red, else green
    var tRedLow = 3.9;
    var tYellowLow = 4.5;
    var tYellowHigh = 10;
    var tRedHigh = 13.4;
    if (unit == Unit.MG_DL) {
        tRedLow = Math.round(tRedLow * 18);
        tYellowLow = Math.round(tYellowLow * 18);
        tYellowHigh = Math.round(tYellowHigh * 18);
        tRedHigh = Math.round(tRedHigh * 18);
    }
    if (value <= tRedLow)      return "#ef4444";
    if (value <= tYellowLow)   return "#f59e0b";
    if (value >= tRedHigh)     return "#ef4444";
    if (value >= tYellowHigh)  return "#f59e0b";
    return "#00c950";
}

// Predicate version of getGlucoseColor's green case. Avoids the brittle
// string-compare on color hex that previously lived in FullRepresentation.qml.
function isInGreenRange(value, unit) {
    var tYellowLow = unit == Unit.MMOL_L ? 4.5 : Math.round(4.5 * 18);
    var tYellowHigh = unit == Unit.MMOL_L ? 10 : Math.round(10 * 18);
    return value > tYellowLow && value < tYellowHigh;
}

function getUnitText(unit) {
    if (unit == Unit.MG_DL) {
        return "mg/dl";
    } else if (unit == Unit.MMOL_L) {
        return "mmol/l";
    }
}
