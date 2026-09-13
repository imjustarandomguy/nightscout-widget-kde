import QtQuick
import QtTest

import "../format.js" as Format

TestCase {
    name: "Format"

    function test_pad2() {
        compare(Format.pad2(0),    "00");
        compare(Format.pad2(5),    "05");
        compare(Format.pad2(12),   "12");
        compare(Format.pad2(99),   "99");
        // Single decimal already-pad is fine; we expect at least 2 chars.
        compare(Format.pad2("00"), "00");
    }

    function test_timeAgo_nullish_returnsEmpty() {
        compare(Format.timeAgo(0), "");
        compare(Format.timeAgo(null), "");
        compare(Format.timeAgo(undefined), "");
    }

    function test_timeAgo_recent() {
        // 30 seconds ago -> "0m ago"
        var t = Date.now() - 30 * 1000;
        compare(Format.timeAgo(t), "0m ago");
    }

    function test_timeAgo_minutes() {
        // 5 minutes, 30 seconds ago -> "5m ago" (floor of minutes)
        var t = Date.now() - 330 * 1000;
        compare(Format.timeAgo(t), "5m ago");
    }

    function test_timeAgo_justUnderOneHour() {
        // 59 minutes ago -> "59m ago" (still in plain minutes)
        var t = Date.now() - 59 * 60 * 1000;
        compare(Format.timeAgo(t), "59m ago");
    }

    function test_timeAgo_exactlyOneHour() {
        // 60 minutes ago -> "1h ago" (no trailing zero minutes)
        var t = Date.now() - 60 * 60 * 1000;
        compare(Format.timeAgo(t), "1h ago");
    }

    function test_timeAgo_90Minutes() {
        // The motivating case: 90 minutes used to render as "90m ago". Now
        // rendered as "1h 30m ago" so older treatments stay scannable.
        var t = Date.now() - 90 * 60 * 1000;
        compare(Format.timeAgo(t), "1h 30m ago");
    }

    function test_timeAgo_threeAndAHalfHours() {
        var t = Date.now() - (3 * 60 + 30) * 60 * 1000;
        compare(Format.timeAgo(t), "3h 30m ago");
    }

    function test_timeAgo_future_isZero() {
        // A future timestamp used to return a negative number of minutes,
        // which read as a bug. Now clamped to "0m ago".
        var t = Date.now() + 60 * 1000;
        compare(Format.timeAgo(t), "0m ago");
    }
}
