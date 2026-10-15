import QtQuick
import QtTest

import "../units.js" as Units

TestCase {
    name: "Units"

    function test_getUnitAwareValue_mgdl() {
        compare(Units.getUnitAwareValue(95.4, Units.Unit.MG_DL), 95);
        compare(Units.getUnitAwareValue(100,   Units.Unit.MG_DL), 100);
    }

    function test_getUnitAwareValue_mmol() {
        // 99 mg/dL -> 5.5 mmol/L
        compare(Units.getUnitAwareValue(99,  Units.Unit.MMOL_L), 5.5);
        // 180 mg/dL -> 10.0 mmol/L
        compare(Units.getUnitAwareValue(180, Units.Unit.MMOL_L), 10.0);
    }

    function test_convertValue_sameUnit_mgdl() {
        compare(Units.convertValue(95.4, Units.Unit.MG_DL, Units.Unit.MG_DL), 95);
    }

    function test_convertValue_sameUnit_mmol() {
        compare(Units.convertValue(5.50, Units.Unit.MMOL_L, Units.Unit.MMOL_L), 5.5);
    }

    function test_convertValue_mgdl_to_mmol() {
        // 99 mg/dL -> 5.5 mmol/L
        compare(Units.convertValue(99,  Units.Unit.MG_DL,  Units.Unit.MMOL_L), 5.5);
        // 180 mg/dL -> 10.0 mmol/L
        compare(Units.convertValue(180, Units.Unit.MG_DL, Units.Unit.MMOL_L), 10.0);
    }

    function test_convertValue_mmol_to_mgdl() {
        // Round-trip should be faithful to one decimal of mmol.
        compare(Units.convertValue(5.5, Units.Unit.MMOL_L, Units.Unit.MG_DL), 99);
        compare(Units.convertValue(10.0, Units.Unit.MMOL_L, Units.Unit.MG_DL), 180);
    }

    function test_parseUnit() {
        compare(Units.parseUnit("mmol/L"), Units.Unit.MMOL_L);
        compare(Units.parseUnit("MMOL/L"), Units.Unit.MMOL_L);
        compare(Units.parseUnit("mg/dl"),  Units.Unit.MG_DL);
        // Falsy or unknown -> mg/dL.
        compare(Units.parseUnit(null), Units.Unit.MG_DL);
        compare(Units.parseUnit(""), Units.Unit.MG_DL);
        compare(Units.parseUnit("foo"), Units.Unit.MG_DL);
    }

    function test_roundChartBound() {
        compare(Units.roundChartBound(0), 0);
        compare(Units.roundChartBound(15.0), 15);
        compare(Units.roundChartBound(15.6), 16);
    }

    function test_convertBound_mgdl_to_mmol() {
        // 270 mg/dL -> 15.0 mmol/L
        compare(Units.convertBound(270, Units.Unit.MG_DL, Units.Unit.MMOL_L), 15.0);
        // 80 mg/dL -> 4.4 mmol/L
        compare(Units.convertBound(80,  Units.Unit.MG_DL, Units.Unit.MMOL_L), 4.4);
    }

    function test_convertBound_mmol_to_mgdl() {
        // 15 mmol/L -> 270 mg/dL
        compare(Units.convertBound(15, Units.Unit.MMOL_L, Units.Unit.MG_DL), 270);
        // 4.4 mmol/L -> 79 mg/dL (4.4 * 18 = 79.2 -> 79)
        compare(Units.convertBound(4.4, Units.Unit.MMOL_L, Units.Unit.MG_DL), 79);
    }

    function test_convertBound_noop() {
        compare(Units.convertBound(95, Units.Unit.MG_DL, Units.Unit.MG_DL), 95);
        compare(Units.convertBound(5.5, Units.Unit.MMOL_L, Units.Unit.MMOL_L), 5.5);
    }

    function test_getGlucoseColor_mgdl() {
        // Red low:    <= 70 mg/dL
        // Yellow low: 71..81 mg/dL
        // Green:      82..179 mg/dL
        // Yellow hi:  180..241 mg/dL
        // Red hi:     >= 242 mg/dL
        compare(Units.getGlucoseColor(70,  Units.Unit.MG_DL), "#ef4444");
        compare(Units.getGlucoseColor(81,  Units.Unit.MG_DL), "#f59e0b");
        compare(Units.getGlucoseColor(110, Units.Unit.MG_DL), "#00c950");
        compare(Units.getGlucoseColor(180, Units.Unit.MG_DL), "#f59e0b");
        compare(Units.getGlucoseColor(242, Units.Unit.MG_DL), "#ef4444");
    }

    function test_getGlucoseColor_mmol() {
        // Thresholds: red<=3.9, yellow<=4.5, green, yellow>=10, red>=13.4
        compare(Units.getGlucoseColor(3.0,  Units.Unit.MMOL_L), "#ef4444");
        compare(Units.getGlucoseColor(4.0,  Units.Unit.MMOL_L), "#f59e0b");
        compare(Units.getGlucoseColor(6.0,  Units.Unit.MMOL_L), "#00c950");
        compare(Units.getGlucoseColor(10.0, Units.Unit.MMOL_L), "#f59e0b");
        compare(Units.getGlucoseColor(14.0, Units.Unit.MMOL_L), "#ef4444");
    }

    function test_isInGreenRange_mgdl() {
        verify(Units.isInGreenRange(82,  Units.Unit.MG_DL));
        verify(Units.isInGreenRange(179, Units.Unit.MG_DL));
        verify(!Units.isInGreenRange(81,  Units.Unit.MG_DL));
        verify(!Units.isInGreenRange(180, Units.Unit.MG_DL));
    }

    function test_isInGreenRange_mmol() {
        verify(Units.isInGreenRange(4.6,  Units.Unit.MMOL_L));
        verify(Units.isInGreenRange(9.9,  Units.Unit.MMOL_L));
        verify(!Units.isInGreenRange(4.5,  Units.Unit.MMOL_L));
        verify(!Units.isInGreenRange(10.0, Units.Unit.MMOL_L));
    }

    function test_getUnitText() {
        compare(Units.getUnitText(Units.Unit.MG_DL),  "mg/dl");
        compare(Units.getUnitText(Units.Unit.MMOL_L), "mmol/l");
    }

    function test_getGlucoseColor_customThresholds_mmol() {
        // Custom thresholds: urgentLow 3.5, targetLow 4.0, targetHigh 8.5, urgentHigh 11.0
        compare(Units.getGlucoseColor(3.4, Units.Unit.MMOL_L, 3.5, 4.0, 8.5, 11.0), "#ef4444");
        compare(Units.getGlucoseColor(3.8, Units.Unit.MMOL_L, 3.5, 4.0, 8.5, 11.0), "#f59e0b");
        compare(Units.getGlucoseColor(6.0, Units.Unit.MMOL_L, 3.5, 4.0, 8.5, 11.0), "#00c950");
        compare(Units.getGlucoseColor(9.0, Units.Unit.MMOL_L, 3.5, 4.0, 8.5, 11.0), "#f59e0b");
        compare(Units.getGlucoseColor(11.5, Units.Unit.MMOL_L, 3.5, 4.0, 8.5, 11.0), "#ef4444");
    }

    function test_getGlucoseColor_customThresholds_mgdl() {
        // Custom thresholds: urgentLow 65, targetLow 75, targetHigh 160, urgentHigh 210
        compare(Units.getGlucoseColor(60, Units.Unit.MG_DL, 65, 75, 160, 210), "#ef4444");
        compare(Units.getGlucoseColor(70, Units.Unit.MG_DL, 65, 75, 160, 210), "#f59e0b");
        compare(Units.getGlucoseColor(120, Units.Unit.MG_DL, 65, 75, 160, 210), "#00c950");
        compare(Units.getGlucoseColor(170, Units.Unit.MG_DL, 65, 75, 160, 210), "#f59e0b");
        compare(Units.getGlucoseColor(220, Units.Unit.MG_DL, 65, 75, 160, 210), "#ef4444");
    }

    function test_isInGreenRange_customThresholds() {
        // Custom target range 4.0 to 8.5
        verify(Units.isInGreenRange(5.0, Units.Unit.MMOL_L, 4.0, 8.5));
        verify(!Units.isInGreenRange(3.9, Units.Unit.MMOL_L, 4.0, 8.5));
        verify(!Units.isInGreenRange(8.6, Units.Unit.MMOL_L, 4.0, 8.5));
    }
}
