import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core
import org.kde.plasma.components
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami

import "../lib/api.js" as Api
import "../lib/charsets.js" as Charsets
import "../lib/constants.js" as Const
import "../lib/format.js" as Format
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
    property string lastSelectedType: Plasmoid.configuration.lastSelectedType

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
    property var chartTimestamps: []
    property var treatments: []
    property var chartTimeStart: 0
    property var chartTimeEnd: 0
    property real pollDelay: 0
    property real pollProgress: 0
    property real pollStartTime: 0
    property bool isStale: false

    // Coarse widget status, consumed by FullRepresentation for the
    // idle / error / offline overlays. Values: "idle" | "ok" | "error" | "offline"
    property string status: "idle"

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

    // When the display unit changes, convert the stored chart bounds so the
    // chart keeps showing a sensible range in the new unit. The converted
    // bounds are persisted back to the config so a downgrade round-trip is
    // faithful to what the user actually sees on screen.
    function applyUnitChange(fromUnit, toUnit) {
        if (fromUnit === toUnit) {
            configChanged();
            return;
        }
        var newMin = Units.convertBound(chartMin, fromUnit, toUnit);
        var newMax = Units.convertBound(chartMax, fromUnit, toUnit);
        Plasmoid.configuration.chartMin = newMin;
        Plasmoid.configuration.chartMax = newMax;
        chartMin = newMin;
        chartMax = newMax;
        configChanged();
    }

    onNightscoutURLChanged: {
        sanitizedNightscoutURL = Utils.trimTrailingChars(nightscoutURL, '/');
        configChanged();
    }
    onNightscoutTokenChanged: configChanged()
    onCharsetChanged: configChanged()
    onChartMinChanged: configChanged()
    onChartMaxChanged: configChanged()
    onPollPaddingChanged: configChanged()
    onLastSelectedTypeChanged: Plasmoid.configuration.lastSelectedType = lastSelectedType

    // Capture the last-seen unit so onUnitsChanged can convert chart bounds
    // from the previous unit to the new one and persist the converted value.
    property int _lastUnits: units
    onUnitsChanged: {
        applyUnitChange(_lastUnits, units);
        _lastUnits = units;
    }

    Timer {
        id: deferTimer
        interval: 50
        repeat: false
        onTriggered: readData()
    }

    // Single-shot timer used for retries and smart-poll scheduling.
    Timer {
        id: textTimer
        interval: Const.RETRY_DELAY_MS
        repeat: false
        running: false
        onTriggered: readData()
    }

    Timer {
        id: timeAgoTimer
        interval: 1000
        repeat: true
        running: true
        onTriggered: {
            timeAgo = Format.timeAgo(lastTimestamp);
            if (lastTimestamp > 0) {
                isStale = Date.now() - lastTimestamp > Const.staleAfterMs(pollPadding);
                // NOTE: we deliberately do NOT mutate glucoseColor here. The
                // full and compact representations own their stale styling via
                // the `isStale` flag; mutating the color here caused a stuck
                // gray color bug since recovery paths never restored it.
            }
        }
    }

    function scheduleNextPoll(fromError) {
        if (fromError) {
            pollDelay = Const.RETRY_DELAY_MS;
            pollStartTime = Date.now();
            pollProgress = 0;
            textTimer.interval = Const.RETRY_DELAY_MS;
            textTimer.start();
            return;
        }
        if (lastTimestamp > 0) {
            var next = lastTimestamp + Const.POLL_PERIOD_MS + pollPadding * 1000;
            var delay = Math.max(Const.MIN_POLL_DELAY_MS, next - Date.now());
            pollDelay = delay;
            pollStartTime = Date.now();
            pollProgress = 0;
            textTimer.interval = delay;
            textTimer.start();
        } else {
            // First-run: no timestamp yet. Poll again shortly so the widget
            // recovers from a transient error before the next sensor reading.
            pollDelay = Const.RETRY_DELAY_MS;
            pollStartTime = Date.now();
            pollProgress = 0;
            textTimer.interval = Const.RETRY_DELAY_MS;
            textTimer.start();
        }
    }

    Timer {
        id: pollProgressTimer
        interval: 200
        repeat: true
        running: textTimer.running
        onTriggered: {
            if (pollDelay > 0) {
                pollProgress = Math.min(0.999, (Date.now() - pollStartTime) / pollDelay);
            } else {
                pollProgress = 0;
            }
        }
    }

    function updateChartBounds() {
        usedChartMin = Units.roundChartBound(chartMin);
        usedChartMax = Units.roundChartBound(chartMax);
    }

    // Refresh only chart and treatments data, without updating glucose/value/
    // timers. Used after a user-submitted treatment so the chart updates
    // without disturbing the polled glucose value or rescheduling the poll.
    function reloadChart() {
        if (Utils.isConfigDefault()) return;
        fetchChartAndTreatments();
    }

    // Fetch 3 hours of entries + treatments. Shared between readData() and
    // reloadChart() so the URL construction and parsing can never drift.
    function fetchChartAndTreatments() {
        updateChartBounds();

        var sinceDate = Date.now() - Const.CHART_HISTORY_MS;
        Api.request(Api.entriesUrl(sanitizedNightscoutURL, nightscoutToken, sinceDate, Const.CHART_ENTRY_COUNT), function (response) {
            try {
                if (response.status == 200 && response.content) {
                    var j = response.content;
                    if (!Array.isArray(j)) return;
                    var valArray = [];
                    var labelArray = [];
                    // Parallel array of timestamps in ms-since-epoch so the
                    // treatment overlay can map a treatment time onto the
                    // index-based x-axis used by Charts.LineChart.
                    var tsArray = [];
                    var i = 0;
                    for (let entry of j.reverse()) {
                        var _glucose = Units.getUnitAwareValue(parseFloat(entry.sgv), units);
                        valArray.push(_glucose);
                        var date = new Date(entry.date);
                        tsArray.push(entry.date);
                        var paddedMinute = Format.pad2(date.getMinutes());
                        if (i++ % Const.LABEL_EVERY_N == 0) {
                            var paddedHour = Format.pad2(date.getHours());
                            labelArray.push(paddedHour + ":" + paddedMinute);
                        } else {
                            labelArray.push("");
                        }
                    }
                    labelSources = labelArray;
                    valueSources = valArray;
                    chartTimestamps = tsArray;
                    if (j.length > 0) {
                        chartTimeStart = j[0].date;
                        chartTimeEnd = j[j.length - 1].date;
                    }
                    // Dynamically expand the chart bounds if data falls outside
                    // the configured range; shrink back when bounds change again.
                    if (valArray.length > 0) {
                        var maxVal = Math.max.apply(null, valArray);
                        var minVal = Math.min.apply(null, valArray);
                        if (maxVal > usedChartMax) usedChartMax = maxVal;
                        if (minVal < usedChartMin) usedChartMin = minVal;
                    }
                } else if (response.error) {
                    console.warn("nightscout: entries fetch error:", response.error);
                }
            } catch (e) {
                console.warn("nightscout: entries parse error:", e.message);
            }
        });

        var sinceTs = Date.now() - Const.CHART_HISTORY_MS;
        Api.request(Api.treatmentsUrl(sanitizedNightscoutURL, nightscoutToken, sinceTs), function (response) {
            try {
                if (response.status == 200 && response.content) {
                    if (Array.isArray(response.content)) {
                        treatments = response.content;
                    }
                } else if (response.error) {
                    console.warn("nightscout: treatments fetch error:", response.error);
                }
            } catch (e) {
                console.warn("nightscout: treatments parse error:", e.message);
            }
        });
    }

    // Read all data from Nightscout using the provided configuration.
    function readData() {
        if (Utils.isConfigDefault()) {
            return;
        }

        updateChartBounds();

        // Get current glucose and trend.
        Api.request(Api.pebbleUrl(sanitizedNightscoutURL, nightscoutToken), function (response) {
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
                    // Determine staleness immediately from the fetched reading
                    // rather than waiting for the 1s timeAgoTimer. Otherwise a
                    // stale reading would briefly show its green/yellow/red
                    // color before the timer flipped isStale to true, and the
                    // next second's timer recompute would still hold the same
                    // value, so this recompute is consistent.
                    isStale = Date.now() - lastTimestamp > Const.staleAfterMs(pollPadding);
                    timeAgo = Format.timeAgo(lastTimestamp);
                    status = "ok";

                    trend = Charsets.getTrendArrow(charset, bgs.trend);
                    scheduleNextPoll(false);
                } else if (response.status === 0) {
                    // Network failure or timeout: keep last value, surface an
                    // "offline" status so the UI can show a useful message
                    // rather than a meaningless "trend = 0".
                    status = "offline";
                    if (glucose === "???") {
                        glucose = qsTr("offline");
                        trend = "⚠";
                    }
                    scheduleNextPoll(true);
                } else {
                    glucose = "ERR";
                    glucoseColor = "white";
                    trend = "⚠";
                    status = "error";
                    scheduleNextPoll(true);
                }
            } catch (e) {
                console.warn("nightscout: pebble parse error:", e.message);
                scheduleNextPoll(true);
            }
        });

        // Chart + treatments fetch (shared with reloadChart).
        fetchChartAndTreatments();
    }
}
