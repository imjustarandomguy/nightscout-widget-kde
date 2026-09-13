import QtQuick
import QtTest

import "../treatments.js" as Treatments

TestCase {
    name: "Timeline-index mapping"

    // 6 entries, 5 minutes apart, starting at 12:00 -> 12:25.
    property var sixEntries: [
        0,    5*60*1000, 10*60*1000, 15*60*1000, 20*60*1000, 25*60*1000
    ]

    // ---- Edge cases ----------------------------------------------------

    function test_emptyTimestamps_returnsZero() {
        compare(Treatments.timestampToFractionalIndex([],        1000), 0);
        compare(Treatments.timestampToFractionalIndex(undefined, 1000), 0);
        compare(Treatments.timestampToFractionalIndex(null,      1000), 0);
    }

    function test_singleTimestamp_returnsZero() {
        compare(Treatments.timestampToFractionalIndex([1000], 500), 0);
    }

    function test_timestampBeforeFirstEntry_returnsZero() {
        // The motivating bug: a treatment at -1ms should still be a valid
        // index (0), not NaN or negative.
        compare(Treatments.timestampToFractionalIndex(sixEntries, -100), 0);
    }

    function test_timestampAtFirstEntry_returnsZero() {
        compare(Treatments.timestampToFractionalIndex(sixEntries, 0), 0);
    }

    // ---- Mid-range interpolation --------------------------------------

    function test_timestampMidpointBetweenTwoEntries() {
        // 12:07:30 (halfway between entry 1 at :05 and entry 2 at :10) ->
        // halfway between index 1 and 2 -> 1.5
        var ts = 7 * 60 * 1000 + 30 * 1000;
        verify(Math.abs(Treatments.timestampToFractionalIndex(sixEntries, ts) - 1.5) < 1e-9);
    }

    function test_timestampMatchesAnEntryExactly() {
        // At 12:15 (entry 3) -> index 3.0
        compare(Treatments.timestampToFractionalIndex(sixEntries, 15 * 60 * 1000), 3.0);
        // At 12:25 (entry 5) -> index 5.0
        compare(Treatments.timestampToFractionalIndex(sixEntries, 25 * 60 * 1000), 5.0);
    }

    // ---- Right-edge ("fresh treatment") -------------------------------

    function test_freshTreatment_extrapolatesPastLastEntry() {
        // This is the key fix: a treatment logged 30 seconds after the last
        // entry should sit just past index 5 (not on the far left). With a
        // 5-minute inter-entry gap (300000 ms), 30s is 1/10 of the gap ->
        // index 5 + 0.1 = 5.1.
        var lastEntryTs = 25 * 60 * 1000;
        var thirtySecLater = lastEntryTs + 30 * 1000;
        var idx = Treatments.timestampToFractionalIndex(sixEntries, thirtySecLater);
        verify(idx > 5.0,     "fresh treatment must extrapolate past last index, got " + idx);
        verify(Math.abs(idx - 5.1) < 1e-9, "expected 5.1, got " + idx);
    }

    function test_freshTreatment_hugeGapIsUnbounded() {
        // A treatment an hour after the last entry should extrapolate to a
        // large index, NOT wrap around or collapse to 0. We just check it
        // is well past the last index.
        var lastEntryTs = 25 * 60 * 1000;
        var oneHourLater = lastEntryTs + 60 * 60 * 1000;
        var idx = Treatments.timestampToFractionalIndex(sixEntries, oneHourLater);
        verify(idx > 5.0 + 10, "expected large extrapolation, got " + idx);
    }

    function test_farInThePast_returnsZero() {
        var idx = Treatments.timestampToFractionalIndex(sixEntries, -1000 * 60 * 60 * 24);
        compare(idx, 0);
    }

    // ---- Non-uniform spacing ------------------------------------------

    function test_nonuniformSpacing_stillInterpolates() {
        // Entries at irregular gaps. The interpolation must respect actual
        // time spacing, not assume uniform gaps. Here the gap from index 1
        // to 2 is 1 minute; from index 2 to 3 is 10 minutes.
        var ct = [0, 5*60*1000, 6*60*1000, 16*60*1000];
        // Halfway in *time* between entry 2 (:06) and entry 3 (:16) is
        // :11.0 -> index 2.5.
        var idx = Treatments.timestampToFractionalIndex(ct, 11 * 60 * 1000);
        compare(idx, 2.5);
    }
}
