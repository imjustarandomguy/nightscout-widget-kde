import QtQuick
import QtTest

import "../treatments.js" as Treatments

TestCase {
    name: "Treatments"

    // buildPayload must produce a JugglucoNG-compatible payload.
    function test_buildPayload_carbs_mealBolus() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("carbs", 25, d);
        compare(payload.eventType, "Meal Bolus");
        compare(payload.enteredBy, "kde-widget");
        compare(payload.app, "kde-widget");
        compare(payload.type, "carbs");
        compare(payload.journalTitle, "Food");
        compare(payload.journalSource, "manual");
        verify(payload._id.startsWith("kde-w-"), "_id must start with kde-w-");
        compare(payload.identifier, payload._id);
        compare(payload.date, d.getTime());
        compare(payload.created_at, "2024-01-01T12:00:00.000Z");
        compare(payload.utcOffset, 0);
        compare(payload.isValid, true);
        compare(payload.carbs, 25);
        compare(payload.food, "Food");
        // defaultAbsorptionMinutes: 60 + 2 * 25 = 110 min
        compare(payload.absorptionTime, 110);
        compare(payload.duration, 110 * 60000);
        compare(payload.durationInMilliseconds, 110 * 60000);
        compare(payload.insulin, null);
    }

    function test_buildPayload_carbs_carbCorrection() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("carbs", 2, d);
        // Under 12g is a Carb Correction
        compare(payload.eventType, "Carb Correction");
        compare(payload.carbs, 2);
        // defaultAbsorptionMinutes: 60 + 2 * 2 = 64 min
        compare(payload.absorptionTime, 64);
        compare(payload.duration, 64 * 60000);
        compare(payload.durationInMilliseconds, 64 * 60000);
    }

    function test_buildPayload_admelog() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("admelog", 10, d);
        compare(payload.eventType, "Correction Bolus");
        compare(payload.enteredBy, "kde-widget");
        compare(payload.app, "kde-widget");
        compare(payload.type, "insulin");
        compare(payload.journalTitle, "Admelog");
        compare(payload.journalSource, "manual");
        verify(payload._id.startsWith("kde-w-"), "_id must start with kde-w-");
        compare(payload.identifier, payload._id);
        compare(payload.date, d.getTime());
        compare(payload.created_at, "2024-01-01T12:00:00.000Z");
        compare(payload.utcOffset, 0);
        compare(payload.isValid, true);
        compare(payload.carbs, null);
        compare(payload.insulin, 10);
        compare(payload.isBasalInsulin, false);
        compare(payload.insulinType, "Admelog");
        compare(payload.notes, "Rapid-Acting");
        compare(payload.insulinOnsetMinutes, 21);
        compare(payload.insulinDurationMinutes, 330);
    }

    function test_buildPayload_tresiba() {
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("tresiba", 25, d);
        compare(payload.eventType, "Correction Bolus");
        compare(payload.enteredBy, "kde-widget");
        compare(payload.app, "kde-widget");
        compare(payload.type, "insulin");
        compare(payload.journalTitle, "Tresiba");
        compare(payload.journalSource, "manual");
        verify(payload._id.startsWith("kde-w-"), "_id must start with kde-w-");
        compare(payload.identifier, payload._id);
        compare(payload.date, d.getTime());
        compare(payload.created_at, "2024-01-01T12:00:00.000Z");
        compare(payload.utcOffset, 0);
        compare(payload.isValid, true);
        compare(payload.carbs, null);
        compare(payload.insulin, 25);
        compare(payload.isBasalInsulin, true);
        compare(payload.insulinType, "Tresiba");
        compare(payload.notes, "Long-Acting");
        compare(payload.insulinOnsetMinutes, 0);
        compare(payload.insulinDurationMinutes, 2520);
    }

    function test_buildPayload_humalog_mappedToAdmelog() {
        // Legacy "humalog" key should map to Admelog
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("humalog", 5, d);
        compare(payload.journalTitle, "Admelog");
        compare(payload.insulinType, "Admelog");
        compare(payload.isBasalInsulin, false);
    }

    function test_buildPayload_unknownType_fallsBackToCarbs() {
        // Unknown type keys should fall back to the first descriptor (carbs)
        var d = new Date("2024-01-01T12:00:00Z");
        var payload = Treatments.buildPayload("nonexistent", 99, d);
        compare(payload.type, "carbs");
        compare(payload.carbs, 99);
    }

    // colorFor tests
    function test_colorFor_carbsOnly_isOrange() {
        compare(Treatments.colorFor({ carbs: 25 }), "#f97316");
    }

    function test_colorFor_carbsAndInsulin_isPurple() {
        compare(Treatments.colorFor({ carbs: 25, insulin: 2 }), "#8e44ad");
    }

    function test_colorFor_jugglucoAdmelog_isPink() {
        // Real JugglucoNG Admelog treatment format
        var t = {
            type: "insulin",
            journalTitle: "Admelog",
            eventType: "Correction Bolus",
            insulin: 10,
            isBasalInsulin: false,
            insulinType: "Admelog",
            notes: "Rapid-Acting",
            carbs: null
        };
        compare(Treatments.colorFor(t), "#ec4899");
    }

    function test_colorFor_jugglucoTresiba_isBlue() {
        // Real JugglucoNG Tresiba treatment format
        var t = {
            type: "insulin",
            journalTitle: "Tresiba",
            eventType: "Correction Bolus",
            insulin: 25,
            isBasalInsulin: true,
            insulinType: "Tresiba",
            notes: "Long-Acting",
            carbs: null
        };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_legacyHumalogInjections_isPink() {
        var t = { insulinInjections: JSON.stringify([{ insulin: "Humalog", units: 1 }]) };
        compare(Treatments.colorFor(t), "#ec4899");
    }

    function test_colorFor_humalogWithBothFields_isPink() {
        var t = {
            insulin: 2,
            insulinInjections: JSON.stringify([{ insulin: "Humalog", units: 2 }])
        };
        compare(Treatments.colorFor(t), "#ec4899");
    }

    function test_colorFor_humalogWithEmptyInjectionsArray_isBlue() {
        var t = {
            insulin: 2,
            insulinInjections: JSON.stringify([])
        };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_legacyTresibaInjections_isBlue() {
        var t = { insulin: 8, insulinInjections: JSON.stringify([{ insulin: "tresiba", units: 8 }]) };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_insulinInjectionsBroken_isBlue() {
        var t = { insulinInjections: "not-json", insulin: 1 };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    function test_colorFor_insulinOnly_isBlue() {
        compare(Treatments.colorFor({ insulin: 2 }), "#3b82f6");
    }

    function test_colorFor_empty_isFallback() {
        compare(Treatments.colorFor({}), "#95a5a6");
    }

    function test_colorFor_cachedRecord_isBlue() {
        var t = { insulinInjections: "", insulin: 5 };
        compare(Treatments.colorFor(t), "#3b82f6");
    }

    // labelFor tests
    function test_labelFor_carbsAndInsulin() {
        compare(Treatments.labelFor({ carbs: 25, insulin: 2.05 }), "25g 2.1u");
    }

    function test_labelFor_carbsOnly() {
        compare(Treatments.labelFor({ carbs: 25 }), "25g");
    }

    function test_labelFor_insulinOnly() {
        compare(Treatments.labelFor({ insulin: 10 }), "10.0u");
    }

    function test_labelFor_notesWhenNoCarbsNoInsulin() {
        compare(Treatments.labelFor({ notes: "walk" }), "walk");
    }

    function test_labelFor_empty_isEmpty() {
        compare(Treatments.labelFor({}), "");
    }

    // timestampFor tests
    function test_timestampFor_timestamp_numeric() {
        compare(Treatments.timestampFor({ timestamp: 1783571834999 }), 1783571834999);
    }

    function test_timestampFor_date_numeric() {
        // JugglucoNG standard epoch ms field
        compare(Treatments.timestampFor({ date: 1791420259735 }), 1791420259735);
    }

    function test_timestampFor_created_at_iso() {
        compare(Treatments.timestampFor({ created_at: "2023-11-14T22:13:20.000Z" }), 1700000000000);
    }

    function test_timestampFor_timestampBeatsDate() {
        compare(Treatments.timestampFor({ timestamp: 1, date: 2 }), 1);
    }

    function test_timestampFor_missing() {
        compare(Treatments.timestampFor({}), 0);
    }

    // typeByKey tests
    function test_typeByKey_known() {
        compare(Treatments.typeByKey("carbs").key,   "carbs");
        compare(Treatments.typeByKey("admelog").key, "admelog");
        compare(Treatments.typeByKey("tresiba").key, "tresiba");
    }

    function test_typeByKey_humalogMapsToAdmelog() {
        compare(Treatments.typeByKey("humalog").key, "admelog");
    }

    function test_typeByKey_unknown_fallsBackToCarbs() {
        compare(Treatments.typeByKey("nope").key, "carbs");
    }

    function test_TYPES_shape() {
        compare(Treatments.TYPES.length, 3);
        compare(Treatments.TYPES[0].key, "carbs");
        compare(Treatments.TYPES[1].key, "admelog");
        compare(Treatments.TYPES[2].key, "tresiba");
        for (var i = 0; i < Treatments.TYPES.length; i++) {
            var t = Treatments.TYPES[i];
            verify(t.key,   "missing key");
            verify(t.label, "missing label");
            verify(t.accent.startsWith("#"), "accent must be a hex color: " + t.accent);
        }
    }
}
