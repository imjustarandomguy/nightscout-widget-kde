import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core
import org.kde.plasma.components
import org.kde.plasma.plasmoid
import org.kde.plasma.components
import org.kde.kirigami as Kirigami

import "../lib/charsets.js" as Charsets
import "../lib/units.js" as Units
import "../lib/utils.js" as Utils

PlasmoidItem {
    id: root

    Plasmoid.configurationRequired: true

    property string nightscoutURL: Plasmoid.configuration.nightscoutURL
    property string nightscoutToken: Plasmoid.configuration.nightscoutToken
    property int charset: Plasmoid.configuration.charset
    property int pollPadding: Plasmoid.configuration.pollPadding
    property int units: Plasmoid.configuration.units
    property real chartMin: Plasmoid.configuration.chartMin
    property real chartMax: Plasmoid.configuration.chartMax

    property real usedChartMin: 0
    property real usedChartMax: 0
    property string sanitizedNightscoutURL: nightscoutURL

    property string glucose: "???"
    property real glucoseValue: 0
    property color glucoseColor: "white"
    property string trend: "???"
    property var lastTimestamp: 0
    property string timeAgo: ""

    property var valueSources: []
    property var labelSources: []
    property var treatments: []
    property var chartTimeStart: 0
    property var chartTimeEnd: 0

    compactRepresentation: CompactRepresentation {}
    fullRepresentation: FullRepresentation {
        Layout.minimumWidth: 650
        Layout.minimumHeight: 480
    }

    // Check if the configuration was adapted completely and try to fetch data.
    function configChanged() {
        if (!Utils.isConfigDefault()) {
            Plasmoid.configurationRequired = false;
            deferTimer.restart();
        }
    }

    onNightscoutURLChanged: {
        sanitizedNightscoutURL = Utils.trimTrailingChars(nightscoutURL, '/');
        configChanged();
    }
    onNightscoutTokenChanged: configChanged()
    onCharsetChanged: configChanged()
    onUnitsChanged: configChanged()
    onChartMinChanged: configChanged()
    onChartMaxChanged: configChanged()
    onPollPaddingChanged: configChanged()

    Timer {
        id: deferTimer
        interval: 50
        repeat: false
        onTriggered: readData()
    }

    // Single-shot timer for smart polling
    Timer {
        id: textTimer
        interval: 1000
        repeat: false
        running: false
        onTriggered: readData()
    }

    Timer {
        id: timeAgoTimer
        interval: 10000
        repeat: true
        running: true
        onTriggered: updateTimeAgo()
    }

    function formatTimeAgo(timestamp) {
        if (!timestamp) return "";
        var minutes = Math.floor((Date.now() - timestamp) / 60000);
        return minutes + "m ago";
    }

    function updateTimeAgo() {
        timeAgo = formatTimeAgo(lastTimestamp);
    }

    function scheduleNextPoll(fromError) {
        if (fromError) {
            textTimer.interval = 30000;
            textTimer.start();
            return;
        }
        if (lastTimestamp > 0) {
            var next = lastTimestamp + 300000 + pollPadding * 1000;
            var delay = Math.max(1000, next - Date.now());
            textTimer.interval = delay;
            textTimer.start();
        }
    }

    function updateChartBounds() {
        usedChartMin = Units.getUnitAwareChartBound(chartMin);
        usedChartMax = Units.getUnitAwareChartBound(chartMax);
    }

    // Read the data from NightScout using the provided configuration.
    function readData() {

        if (Utils.isConfigDefault()) {
            return;
        }

        updateChartBounds();

        // get current glucose and trend
        Utils.sendJsonRequest(sanitizedNightscoutURL + "/pebble/?token=" + nightscoutToken, function (response) {
            try {
                if (response.status == 200 && response.content) {
                    var j = response.content;
                    var bgs = j.bgs ? j.bgs[0] : null;

                    if (!bgs) { scheduleNextPoll(true); return; }
                    var sgv = parseFloat(bgs.sgv);
                    var apiUnit = Units.parseUnit(j.units);
                    if (apiUnit === Units.Unit.MG_DL && sgv < 30) {
                        apiUnit = Units.Unit.MMOL_L;
                    }
                    glucoseValue = Units.convertValue(sgv, apiUnit, units);
                    glucose = units === Units.Unit.MMOL_L ? glucoseValue.toFixed(1) : glucoseValue;
                    glucoseColor = Units.getGlucoseColor(glucoseValue, units);
                    lastTimestamp = bgs.datetime;
                    updateTimeAgo();

                    trend = Charsets.getTrendArrow(charset, bgs.trend);
                    scheduleNextPoll(false);
                } else {
                    glucose = "ERR";
                    glucoseColor = "white";
                    trend = response.status;
                    scheduleNextPoll(true);
                }
            } catch(e) {
                scheduleNextPoll(true);
            }
        });

        // get last 3 hours' data for the chart
        Utils.sendJsonRequest(sanitizedNightscoutURL + "/api/v1/entries.json?count=37&token=" + nightscoutToken, function (response) {
            try {
                if (response.status == 200 && response.content) {
                    var j = response.content;

                    if (!Array.isArray(j)) return;
                    var valArray = [];
                    var labelArray = [];

                    var i = 0;

                    for (let entry of j.reverse()) {
                        var _glucose = Units.getUnitAwareValue(parseFloat(entry.sgv), units);
                        valArray.push(_glucose);

                        var date = new Date(entry.date);
                        var paddedMinute = Utils.padTo2Digits(date.getMinutes());

                        if (i++ % 4 == 0) {
                            var paddedHour = Utils.padTo2Digits(date.getHours());
                            labelArray.push(paddedHour + ":" + paddedMinute);
                        } else {
                            labelArray.push("");
                        }
                    }

                    labelSources = labelArray;
                    valueSources = valArray;

                    if (j.length > 0) {
                        chartTimeStart = j[0].date;
                        chartTimeEnd = j[j.length - 1].date;
                    }

                    // dynamically scale the chart if we are out of bounds!
                    if (Math.max(...valArray) > usedChartMax) {
                        usedChartMax = Math.max(...valArray);
                    }

                    if (Math.min(...valArray) < usedChartMin) {
                        usedChartMin = Math.min(...valArray);
                    }
                }
            } catch(e) {}
        });

        // get treatments from the last 3 hours
        var sinceTime = new Date(Date.now() - 3 * 60 * 60 * 1000).toISOString();
        Utils.sendJsonRequest(sanitizedNightscoutURL + "/api/v1/treatments.json?find[created_at][$gte]=" + sinceTime + "&token=" + nightscoutToken, function (response) {
            try {
                if (response.status == 200 && response.content) {
                    if (Array.isArray(response.content)) {
                        treatments = response.content;
                    }
                }
            } catch(e) {}
        });
    }
}
