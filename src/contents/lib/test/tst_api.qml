import QtQuick
import QtTest

import "../api.js" as Api

TestCase {
    name: "Api"

    function test_pebbleUrl() {
        compare(Api.pebbleUrl("https://ns.example.com", ""), "https://ns.example.com/pebble/");
        compare(Api.pebbleUrl("https://ns.example.com", "secret123"), "https://ns.example.com/pebble/?token=secret123");
    }

    function test_entriesUrl() {
        var urlNoToken = Api.entriesUrl("https://ns.example.com", "", 1000, 50);
        compare(urlNoToken, "https://ns.example.com/api/v1/entries.json?find%5Bdate%5D%5B%24gte%5D=1000&count=50");

        var urlWithToken = Api.entriesUrl("https://ns.example.com", "secret123", 1000, 50);
        compare(urlWithToken, "https://ns.example.com/api/v1/entries.json?find%5Bdate%5D%5B%24gte%5D=1000&count=50&token=secret123");
    }

    function test_treatmentsUrl() {
        var since = 1700000000000;
        var iso = encodeURIComponent(new Date(since).toISOString());
        var url = Api.treatmentsUrl("https://ns.example.com", "tok", since);
        compare(url, "https://ns.example.com/api/v1/treatments.json?find%5Bcreated_at%5D%5B%24gte%5D=" + iso + "&token=tok");
    }

    function test_postTreatmentUrl() {
        compare(Api.postTreatmentUrl("https://ns.example.com", ""), "https://ns.example.com/api/v1/treatments/");
        compare(Api.postTreatmentUrl("https://ns.example.com", "tok"), "https://ns.example.com/api/v1/treatments/?token=tok");
    }

    function test_deleteTreatmentUrl() {
        compare(Api.deleteTreatmentUrl("https://ns.example.com", "", "66123456789"), "https://ns.example.com/api/v1/treatments/66123456789");
        compare(Api.deleteTreatmentUrl("https://ns.example.com", "tok", "66123456789"), "https://ns.example.com/api/v1/treatments/66123456789?token=tok");
        compare(Api.deleteTreatmentUrl("https://ns.example.com", "tok", "kde-w-abc-123"), "https://ns.example.com/api/v1/treatments/kde-w-abc-123?token=tok");
    }
}
