import QtQuick
import QtTest

import "../treatments.js" as Treatments

TestCase {
    name: "Treatments"

    // buildPayload must produce an xDrip-compatible payload.
    function test_buildPayload_carbs() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("carbs", 25, d);
        compare(payload.eventType, "<none>");
        compare(payload.enteredBy, "kde-widget");
        verify(typeof payload.uuid === "string", "uuid must be present");
        compare(payload.timestamp, d.getTime());
        compare(payload.created_at, "2024-01-01T12:00:00.000Z");
        compare(payload.utcOffset, 0);
        compare(payload.carbs, 25);
        compare(payload.insulin, null);
        compare(payload.insulinInjections, "[]");
    }

    function test_buildPayload_humalog() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("humalog", 2.1, d);
        compare(payload.eventType, "<none>");
        compare(payload.enteredBy, "kde-widget");
        verify(typeof payload.uuid === "string", "uuid must be present");
        compare(payload.timestamp, d.getTime());
        compare(payload.carbs, null);
        compare(payload.insulin, 2.1);
        var injections = JSON.parse(payload.insulinInjections);
        compare(injections[0].insulin, "Humalog");
        compare(injections[0].units, 2.1);
    }

    function test_buildPayload_tresiba() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("tresiba", 8, d);
        compare(payload.insulin, 8);
        var injections = JSON.parse(payload.insulinInjections);
        compare(injections[0].insulin, "tresiba");
        compare(injections[0].units, 8);
    }

    function test_buildPayload_unknownType_fallsBackToCarbs() {
        // Unknown type keys should fall back to the first descriptor (carbs)
        // so the UI never builds a payload it cannot parse on the server side.
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("nonexistent", 99, d);
        compare(payload.eventType, "<none>");
        compare(payload.carbs, 99);
    }

    // colorFor: the priority order is insulinInjections(Humalog) >
    // carbs+insulin > carbs-only > insulin > fallback. The Humalog
    // insulinInjections check runs first so a Humalog record never gets
    // shadowed by the generic "insulin -> blue" branch.
    function test_colorFor_carbsOnly_isOrange() {
        compare(Treatments.colorFor({ carbs: 25 }), "#f97316");
    }

    function test_colorFor_carbsAndNonHumalogInsulin_isPurple() {
        compare(Treatments.colorFor({ carbs: 25, insulin: 2 }), "#8e44ad");
    }

    function test_colorFor_insulinOnly_isBlue() {
        compare(Treatments.colorFor({ insulin: 2 }), "#3b82f6");
    }

    function test_colorFor_insulinInjectionsHumalog_isPink() {
        var t = { insulinInjections: JSON.stringify([{ insulin: "Humalog", units: 1 }]) };
        compare(Treatments.colorFor(t), "#ec4899");
    }

    function test_colorFor_humalogWithBothFields_isPink() {
        // Bug repro: a Humalog record that the Nightscout API returns with
        // both `insulin` set and the JSON `insulinInjections` array.
        // Previously the function checked `insulinInjections` after `carbs`
        // and `insulin`, so if the JSON branch fell through (here it
        // succeeds, but the logic placed it before the carbohydrate rule),
        // pink could be masked by the generic "insulin -> blue" branch.
        // Pink must win.
        var t = {
            insulin: 2,
            insulinInjections: JSON.stringify([{ insulin: "Humalog", units: 2 }])
        };
        compare(Treatments.colorFor(t), "#ec4899");
    }

    function test_colorFor_humalogWithEmptyInjectionsArray_isPink() {
        // Defensive: if the API returns an `insulinInjections` field but
        // the array is empty, the JSON parses cleanly but produces no
        // Humalog indicator. In the buggy ordering, that fell through to
        // the generic "insulin -> blue" branch even when `insulin`
        // equals "Humalog" elsewhere. The new ordering still falls
        // through here, but the empty-array record is unusual in
        // practice; document the behavior with this test.
        var t = {
            insulin: 2,
            insulinInjections: JSON.stringify([])
        };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_insulinInjectionsOther_isBlue() {
        // xDrip always sets both `insulin` and `insulinInjections` for insulin
        // treatments, even for non-Humalog types.
        var t = { insulin: 8, insulinInjections: JSON.stringify([{ insulin: "tresiba", units: 8 }]) };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_insulinInjectionsBroken_isBlue() {
        // Invalid JSON in insulinInjections should not throw; it should fall
        // through to the generic insulin/blue path.
        var t = { insulinInjections: "not-json", insulin: 1 };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_empty_isFallback() {
        compare(Treatments.colorFor({}), "#95a5a6");
    }

    function test_colorFor_cachedRecord_isBlue() {
        // An empty-string `insulinInjections` (a length-0 truthy string)
        // fails JSON.parse and falls through to the generic blue.
        var t = { insulinInjections: "", insulin: 5 };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_labelFor_carbsAndInsulin() {
        compare(Treatments.labelFor({ carbs: 25, insulin: 2.05 }), "25g 2.1u");
    }

    function test_labelFor_carbsOnly() {
        compare(Treatments.labelFor({ carbs: 25 }), "25g");
    }

    function test_labelFor_notesWhenNoCarbsNoInsulin() {
        compare(Treatments.labelFor({ notes: "walk" }), "walk");
    }

    function test_labelFor_empty_isEmpty() {
        compare(Treatments.labelFor({}), "");
    }

    function test_timestampFor_timestamp_numeric() {
        // xDrip's primary timestamp field takes priority.
        compare(Treatments.timestampFor({ timestamp: 1783571834999 }), 1783571834999);
    }

    function test_timestampFor_date_numeric() {
        compare(Treatments.timestampFor({ date: 1700000000000 }), 1700000000000);
    }

    function test_timestampFor_created_at_iso() {
        compare(Treatments.timestampFor({ created_at: "2023-11-14T22:13:20.000Z" }), 1700000000000);
    }

    function test_timestampFor_timestampBeatsDate() {
        // timestamp should be checked before date.
        compare(Treatments.timestampFor({ timestamp: 1, date: 2 }), 1);
    }

    function test_timestampFor_missing() {
        compare(Treatments.timestampFor({}), 0);
    }

    function test_typeByKey_known() {
        compare(Treatments.typeByKey("carbs").key,   "carbs");
        compare(Treatments.typeByKey("humalog").key, "humalog");
        compare(Treatments.typeByKey("tresiba").key, "tresiba");
    }

    function test_typeByKey_unknown_fallsBackToCarbs() {
        compare(Treatments.typeByKey("nope").key, "carbs");
    }

    function test_TYPES_shape() {
        compare(Treatments.TYPES.length, 3);
        for (var i = 0; i < Treatments.TYPES.length; i++) {
            var t = Treatments.TYPES[i];
            verify(t.key,   "missing key");
            verify(t.label, "missing label");
            verify(t.accent.startsWith("#"), "accent must be a hex color: " + t.accent);
        }
    }
}
