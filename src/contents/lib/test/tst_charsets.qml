import QtQuick
import QtTest

import "../charsets.js" as Charsets

TestCase {
    name: "Charsets"

    // All three charsets must provide a symbol for every trend index used by
    // the Nightscout API (0..9). Index 0 (NONE) is the empty/blank symbol.
    function test_allIndicesHaveSymbol() {
        var sets = [
            Charsets.Charset.UNICODE_1,
            Charsets.Charset.UNICODE_2,
            Charsets.Charset.EMOJI
        ];
        for (var i = 0; i < sets.length; i++) {
            for (var trend = 0; trend <= 9; trend++) {
                var symbol = Charsets.getTrendArrow(sets[i], trend);
                verify(symbol !== undefined, "charset " + i + " trend " + trend);
                if (trend === 0) {
                    compare(symbol, "", "index 0 should be blank, not a unicode arrow");
                } else {
                    verify(symbol.length > 0, "charset " + i + " trend " + trend + " must have a glyph");
                }
            }
        }
    }

    // Bounds-style validation off the edges too: an out-of-range trend index
    // used to silently return undefined. Guard the contract by enumerating the
    // valid range and ensuring getTrendArrow returns a string.
    function test_getTrendArrow_returnsString() {
        for (var i = 0; i <= 9; i++) {
            var s = Charsets.getTrendArrow(Charsets.Charset.UNICODE_1, i);
            compare(typeof s, "string");
        }
    }

    function test_getCharsetText() {
        var t0 = Charsets.getCharsetText(Charsets.Charset.UNICODE_1);
        var t1 = Charsets.getCharsetText(Charsets.Charset.UNICODE_2);
        var t2 = Charsets.getCharsetText(Charsets.Charset.EMOJI);
        verify(t0.indexOf("Unicode 1") === 0);
        verify(t1.indexOf("Unicode 2") === 0);
        verify(t2.indexOf("Emoji") === 0);
    }
}
