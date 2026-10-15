import QtQuick
import QtQuick.Layouts

import org.kde.plasma.plasmoid

import "../lib/api.js" as Api
import "../lib/charsets.js" as Charsets
import "../lib/constants.js" as Const
import "../lib/format.js" as Format
import "../lib/units.js" as Units
import "../lib/utils.js" as Utils

PlasmoidItem {
    id: root

    Plasmoid.configurationRequired: true

    toolTipMainText: (glucose !== "???" ? glucose + " " + Units.getUnitText(units) + (trend ? " " + trend : "") + (glucoseDelta ? " (" + glucoseDelta + ")" : "") : qsTr("Nightscout Widget"))
    toolTipSubText: {
        let parts = [];
        if (lastTimestamp > 0) {
            parts.push(isStale ? qsTr("Stale (%1)").arg(timeAgo) : timeAgo);
        }
        if (status === "ok") {
            parts.push(Units.isInGreenRange(glucoseValue, units, targetLow, targetHigh) ? qsTr("In Target Range") : qsTr("Out of Target Range"));
        } else if (status === "offline") {
            parts.push(qsTr("Offline — retrying"));
        } else if (status === "error") {
            parts.push(qsTr("Error connecting to Nightscout"));
        }
        return parts.join(" · ");
    }

    property string nightscoutURL: Plasmoid.configuration.nightscoutURL
    property string nightscoutToken: Plasmoid.configuration.nightscoutToken
    property int charset: Plasmoid.configuration.charset
    property int pollPadding: Plasmoid.configuration.pollPadding
    property int units: Plasmoid.configuration.units
    property real chartMin: Plasmoid.configuration.chartMin
    property real chartMax: Plasmoid.configuration.chartMax
    property string lastSelectedType: Plasmoid.configuration.lastSelectedType
    property real urgentLow: Plasmoid.configuration.urgentLow
    property real targetLow: Plasmoid.configuration.targetLow
    property real targetHigh: Plasmoid.configuration.targetHigh
    property real urgentHigh: Plasmoid.configuration.urgentHigh
    property int chartHours: Plasmoid.configuration.chartHours
    property string rapidName: Plasmoid.configuration.rapidName
    property string basalName: Plasmoid.configuration.basalName
    property bool showBasal: Plasmoid.configuration.showBasal

    property real usedChartMin: 0
    property real usedChartMax: 0
    property string sanitizedNightscoutURL: nightscoutURL

    property string glucose: "???"
    property real glucoseValue: 0
    property color glucoseColor: "white"
    property string trend: "???"
    property string glucoseDelta: ""
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
        if (!Utils.isConfigDefault(sanitizedNightscoutURL, nightscoutToken)) {
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
        // Only convert if chartMax is still scaled in the old unit.
        // If configGeneral already converted it, avoid double-converting!
        var needsConvert = false;
        if (fromUnit === Units.Unit.MMOL_L && toUnit === Units.Unit.MG_DL) {
            needsConvert = chartMax > 0 && chartMax < 40;
        } else if (fromUnit === Units.Unit.MG_DL && toUnit === Units.Unit.MMOL_L) {
            needsConvert = chartMax > 70;
        }
        if (needsConvert) {
            let newMin = Units.convertBound(chartMin, fromUnit, toUnit);
            let newMax = Units.convertBound(chartMax, fromUnit, toUnit);
            Plasmoid.configuration.chartMin = newMin;
            Plasmoid.configuration.chartMax = newMax;
            chartMin = newMin;
            chartMax = newMax;

            let newUrgentLow = Units.convertBound(urgentLow, fromUnit, toUnit);
            let newTargetLow = Units.convertBound(targetLow, fromUnit, toUnit);
            let newTargetHigh = Units.convertBound(targetHigh, fromUnit, toUnit);
            let newUrgentHigh = Units.convertBound(urgentHigh, fromUnit, toUnit);
            Plasmoid.configuration.urgentLow = newUrgentLow;
            Plasmoid.configuration.targetLow = newTargetLow;
            Plasmoid.configuration.targetHigh = newTargetHigh;
            Plasmoid.configuration.urgentHigh = newUrgentHigh;
            urgentLow = newUrgentLow;
            targetLow = newTargetLow;
            targetHigh = newTargetHigh;
            urgentHigh = newUrgentHigh;
        }
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
    onUrgentLowChanged: configChanged()
    onTargetLowChanged: configChanged()
    onTargetHighChanged: configChanged()
    onUrgentHighChanged: configChanged()
    onChartHoursChanged: reloadChart()
    onRapidNameChanged: Plasmoid.configuration.rapidName = rapidName
    onBasalNameChanged: Plasmoid.configuration.basalName = basalName
    onShowBasalChanged: Plasmoid.configuration.showBasal = showBasal

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
            let next = lastTimestamp + Const.POLL_PERIOD_MS + pollPadding * 1000;
            let delay = Math.max(Const.MIN_POLL_DELAY_MS, next - Date.now());
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
        interval: 1000
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
        // Defensive check: if units is mg/dL but stored max is in mmol/L scale (< 35)
        if (units === Units.Unit.MG_DL && usedChartMax > 0 && usedChartMax < 35) {
            usedChartMax = Math.round(usedChartMax * 18);
        } else if (units === Units.Unit.MMOL_L && usedChartMax > 70) {
            usedChartMax = parseFloat((usedChartMax / 18).toFixed(1));
        }

        // Defensive checks for thresholds:
        if (units === Units.Unit.MG_DL && urgentHigh > 0 && urgentHigh < 35) {
            urgentLow = Math.round(urgentLow * 18);
            targetLow = Math.round(targetLow * 18);
            targetHigh = Math.round(targetHigh * 18);
            urgentHigh = Math.round(urgentHigh * 18);
            Plasmoid.configuration.urgentLow = urgentLow;
            Plasmoid.configuration.targetLow = targetLow;
            Plasmoid.configuration.targetHigh = targetHigh;
            Plasmoid.configuration.urgentHigh = urgentHigh;
        } else if (units === Units.Unit.MMOL_L && urgentLow > 40) {
            urgentLow = parseFloat((urgentLow / 18).toFixed(1));
            targetLow = parseFloat((targetLow / 18).toFixed(1));
            targetHigh = parseFloat((targetHigh / 18).toFixed(1));
            urgentHigh = parseFloat((urgentHigh / 18).toFixed(1));
            Plasmoid.configuration.urgentLow = urgentLow;
            Plasmoid.configuration.targetLow = targetLow;
            Plasmoid.configuration.targetHigh = targetHigh;
            Plasmoid.configuration.urgentHigh = urgentHigh;
        }
    }

    // Refresh only chart and treatments data, without updating glucose/value/
    // timers. Used after a user-submitted treatment so the chart updates
    // without disturbing the polled glucose value or rescheduling the poll.
    function reloadChart() {
        if (Utils.isConfigDefault(sanitizedNightscoutURL, nightscoutToken)) return;
        fetchChartAndTreatments();
    }

    // Fetch entries + treatments for the configured timeframe. Shared between
    // readData() and reloadChart() so the URL construction and parsing never drift.
    function fetchChartAndTreatments() {
        updateChartBounds();

        var hours = (chartHours > 0) ? chartHours : 3;
        var historyMs = hours * 3600000;
        var entryCount = Math.max(100, hours * 30);
        var labelStride = Math.max(4, Math.round(hours * 2));
        var sinceDate = Date.now() - historyMs;

        Api.request(Api.entriesUrl(sanitizedNightscoutURL, nightscoutToken, sinceDate, entryCount), function (response) {
            try {
                if (response.status == 200 && response.content) {
                    let j = response.content;
                    if (!Array.isArray(j)) return;
                    let valArray = [];
                    let labelArray = [];
                    // Parallel array of timestamps in ms-since-epoch so the
                    // treatment overlay can map a treatment time onto the
                    // index-based x-axis used by Charts.LineChart.
                    let tsArray = [];
                    let i = 0;
                    for (let entry of j.reverse()) {
                        let _glucose = Units.getUnitAwareValue(parseFloat(entry.sgv), units);
                        valArray.push(_glucose);
                        let date = new Date(entry.date);
                        tsArray.push(entry.date);
                        let paddedMinute = Format.pad2(date.getMinutes());
                        if (i++ % labelStride == 0) {
                            let paddedHour = Format.pad2(date.getHours());
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
                    if (valArray.length >= 2) {
                        let curr = valArray[valArray.length - 1];
                        let prev = valArray[valArray.length - 2];
                        if (typeof curr === "number" && typeof prev === "number" && !isNaN(curr) && !isNaN(prev)) {
                            let diff = curr - prev;
                            if (units === Units.Unit.MMOL_L) {
                                let diffFmt = diff.toFixed(1);
                                glucoseDelta = (diff > 0 ? "+" : "") + diffFmt;
                            } else {
                                let diffRound = Math.round(diff);
                                glucoseDelta = (diffRound > 0 ? "+" : "") + diffRound;
                            }
                        }
                    }
                    // Dynamically expand the chart bounds if data falls outside
                    // the configured range; shrink back when bounds change again.
                    if (valArray.length > 0) {
                        let validVals = valArray.filter(v => typeof v === "number" && !isNaN(v));
                        if (validVals.length > 0) {
                            let maxVal = Math.max.apply(null, validVals);
                            let minVal = Math.min.apply(null, validVals);
                            if (maxVal > usedChartMax) usedChartMax = maxVal;
                            if (minVal < usedChartMin) usedChartMin = minVal;
                        }
                    }
                    if (usedChartMax <= usedChartMin) {
                        usedChartMax = usedChartMin + (units === Units.Unit.MMOL_L ? 5 : 50);
                    }
                } else if (response.error) {
                    console.warn("nightscout: entries fetch error:", response.error);
                }
            } catch (e) {
                console.warn("nightscout: entries parse error:", e.message);
            }
        });

        var sinceTs = Date.now() - historyMs;
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
        if (Utils.isConfigDefault(sanitizedNightscoutURL, nightscoutToken)) {
            return;
        }

        updateChartBounds();

        // Get current glucose and trend.
        Api.request(Api.pebbleUrl(sanitizedNightscoutURL, nightscoutToken), function (response) {
            try {
                if (response.status == 200 && response.content) {
                    let j = response.content;
                    let bgs = j.bgs ? j.bgs[0] : null;

                    if (!bgs) { scheduleNextPoll(true); return; }
                    let sgv = parseFloat(bgs.sgv);
                    let apiUnit = Units.parseUnit(j.units);
                    // If the API reported mg/dL but the raw reading string includes a decimal
                    // point (e.g. "8.0"), it is actually mmol/L. Only use this check rather than
                    // overriding genuine severe hypoglycemia (e.g. 25 mg/dL).
                    if (apiUnit === Units.Unit.MG_DL && String(bgs.sgv).indexOf('.') !== -1) {
                        apiUnit = Units.Unit.MMOL_L;
                    }
                    glucoseValue = Units.convertValue(sgv, apiUnit, units);
                    glucose = units === Units.Unit.MMOL_L ? glucoseValue.toFixed(1) : String(glucoseValue);
                    glucoseColor = Units.getGlucoseColor(glucoseValue, units, root.urgentLow, root.targetLow, root.targetHigh, root.urgentHigh);
                    lastTimestamp = bgs.datetime;

                    if (bgs.bgdelta !== undefined && bgs.bgdelta !== null) {
                        let rawDelta = parseFloat(bgs.bgdelta);
                        if (!isNaN(rawDelta)) {
                            if (units === Units.Unit.MMOL_L) {
                                let dMmol = (apiUnit === Units.Unit.MMOL_L ? rawDelta : rawDelta * Units.MMOL_PER_MGDL).toFixed(1);
                                glucoseDelta = (parseFloat(dMmol) > 0 ? "+" : "") + dMmol;
                            } else {
                                let dMg = Math.round(apiUnit === Units.Unit.MMOL_L ? rawDelta / Units.MMOL_PER_MGDL : rawDelta);
                                glucoseDelta = (dMg > 0 ? "+" : "") + dMg;
                            }
                        }
                    }
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
