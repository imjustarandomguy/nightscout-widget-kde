const Unit = {
    MG_DL: 0,
    MMOL_L: 1
}

function getUnitAwareValue(mgPDl, unit) {
    // Input is always in mg/dL (raw sensor value)
    if (unit == Unit.MG_DL) {
        return Math.round(mgPDl);
    } else if (unit == Unit.MMOL_L) {
        return parseFloat((mgPDl / 18).toFixed(1));
    }
}

function convertValue(value, fromUnit, toUnit) {
    // Convert a value between units (handles API responses in either unit)
    if (fromUnit == toUnit) {
        // No conversion needed, just format
        if (toUnit == Unit.MMOL_L) {
            return parseFloat(value.toFixed(1));
        }
        return Math.round(value);
    }
    // Convert via mg/dL
    var mgDl = fromUnit == Unit.MMOL_L ? value * 18 : value;
    if (toUnit == Unit.MMOL_L) {
        return parseFloat((mgDl / 18).toFixed(1));
    }
    return Math.round(mgDl);
}

function parseUnit(text) {
    // Parse API response unit string to Unit constant
    if (text && text.toLowerCase().indexOf("mmol") !== -1) {
        return Unit.MMOL_L;
    }
    return Unit.MG_DL;
}

function getUnitAwareChartBound(value) {
    return Math.round(value);
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
    return "#22c55e";
}

function getUnitText(unit) {
    if (unit == Unit.MG_DL) {
        return "mg/dl";
    } else if (unit == Unit.MMOL_L) {
        return "mmol/l";
    }
}
