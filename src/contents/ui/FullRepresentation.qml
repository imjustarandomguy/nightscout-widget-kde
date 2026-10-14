import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls as ChartsControls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

import "../lib/api.js" as Api
import "../lib/format.js" as Format
import "../lib/treatments.js" as Treatments
import "../lib/units.js" as Units
import "../lib/utils.js" as Utils

ColumnLayout {
    id: diagramRoot

    anchors.fill: parent

    spacing: 0

    Item {
        id: chartArea
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 650

        // ---- Header card -------------------------------------------------
        Rectangle {
            id: headerBg
            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                bottom: headerLayout.bottom
                bottomMargin: -Kirigami.Units.mediumSpacing
            }
            color: Qt.rgba(Kirigami.Theme.textColor.r,
                           Kirigami.Theme.textColor.g,
                           Kirigami.Theme.textColor.b, 0.04)
            radius: Kirigami.Units.largeSpacing
            border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                  Kirigami.Theme.textColor.g,
                                  Kirigami.Theme.textColor.b, 0.08)
            border.width: 1
        }

        ColumnLayout {
            id: headerLayout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                leftMargin: Kirigami.Units.largeSpacing
                rightMargin: Kirigami.Units.largeSpacing
                topMargin: Kirigami.Units.mediumSpacing
            }

            spacing: 2

            // Row 1: Glucose + trend arrow + unit
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true }

                Label {
                    id: currentBG
                    text: glucose
                    color: isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : glucoseColor
                    font.pointSize: 42
                    font.weight: Font.Black
                    Layout.alignment: Qt.AlignVCenter

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "black"
                        shadowBlur: 0.4
                        shadowHorizontalOffset: 0
                        shadowVerticalOffset: 0
                    }
                }

                Label {
                    id: trendLabel
                    text: trend
                    color: isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : glucoseColor
                    font.pointSize: 28
                    font.weight: Font.Bold
                    Layout.alignment: Qt.AlignVCenter
                    leftPadding: 4
                    rightPadding: 6
                    topPadding: 4
                    bottomPadding: 6
                }

                Label {
                    id: unitLabel
                    text: Units.getUnitText(units)
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: 13
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                    leftPadding: 2
                }

                Item { Layout.fillWidth: true }
            }

            // Row 2: Delta badge + status dot + time-ago
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                Item { Layout.fillWidth: true }

                Rectangle {
                    id: deltaBadge
                    visible: root.glucoseDelta !== ""
                    implicitWidth: deltaLabel.implicitWidth + 12
                    implicitHeight: 20
                    radius: 5
                    color: Qt.rgba(Kirigami.Theme.textColor.r,
                                   Kirigami.Theme.textColor.g,
                                   Kirigami.Theme.textColor.b, 0.08)
                    border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                          Kirigami.Theme.textColor.g,
                                          Kirigami.Theme.textColor.b, 0.16)
                    border.width: 1
                    Layout.alignment: Qt.AlignVCenter

                    Label {
                        id: deltaLabel
                        anchors.centerIn: parent
                        text: root.glucoseDelta
                        color: isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : Kirigami.Theme.textColor
                        font.pointSize: 10
                        font.weight: Font.DemiBold
                    }
                }

                Label {
                    text: "·"
                    visible: deltaBadge.visible
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: 10
                    Layout.alignment: Qt.AlignVCenter
                }

                Rectangle {
                    width: 8
                    height: 8
                    radius: width / 2
                    color: isStale ? "#f59e0b"
                                   : (Units.isInGreenRange(glucoseValue, units) ? "#00c950" : glucoseColor)
                    Layout.alignment: Qt.AlignVCenter
                    Behavior on color { ColorAnimation { duration: 200 } }
                }

                Label {
                    text: isStale ? qsTr("stale · %1").arg(timeAgo) : timeAgo
                    color: Kirigami.Theme.disabledTextColor
                    font.pointSize: 10
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }
        }

        // ---- Target range band ------------------------------------------
        Rectangle {
            id: targetBand
            anchors {
                left: lineChart.left
                right: lineChart.right
                top: lineChart.top
                bottom: lineChart.bottom
            }
            color: "transparent"
            visible: usedChartMax > usedChartMin

            property real tLow: units === Units.Unit.MMOL_L ? 4.5 : Math.round(4.5 * 18)
            property real tHigh: units === Units.Unit.MMOL_L ? 10 : Math.round(10 * 18)
            property real range: usedChartMax - usedChartMin
            property real yHigh: range > 0 ? (usedChartMax - tHigh) / range * height : 0
            property real yLow: range > 0 ? (usedChartMax - tLow) / range * height : 0

            // Green in-range band drawn proportionally to chart geometry
            Rectangle {
                id: inRangeHighlight
                color: Qt.rgba(0, 0.788, 0.5, 0.08)
                radius: 2
                // band covers from tLow to tHigh in chart coordinates
                property real clampedHigh: Math.min(usedChartMax, targetBand.tHigh)
                property real clampedLow: Math.max(usedChartMin, targetBand.tLow)
                property real yTop: targetBand.range > 0 ? (usedChartMax - clampedHigh) / targetBand.range * parent.height : 0
                property real bandH: targetBand.range > 0 ? (clampedHigh - clampedLow) / targetBand.range * parent.height : 0
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.max(0, yTop)
                height: Math.min(parent.height - y, Math.max(0, bandH))
                visible: targetBand.range > 0 && targetBand.tLow < usedChartMax && targetBand.tHigh > usedChartMin
            }

            // Upper target boundary guideline & edge marker
            Rectangle {
                id: highGuideLine
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(targetBand.yHigh)
                height: 1
                color: Qt.rgba(0, 0.788, 0.5, 0.35)
                visible: targetBand.range > 0 && targetBand.tHigh <= usedChartMax && targetBand.tHigh >= usedChartMin

                Label {
                    anchors.right: parent.right
                    anchors.bottom: parent.top
                    anchors.rightMargin: 4
                    anchors.bottomMargin: 1
                    text: units === Units.Unit.MMOL_L ? targetBand.tHigh.toFixed(1) : targetBand.tHigh.toString()
                    font.pointSize: 8
                    font.weight: Font.Medium
                    color: Qt.rgba(0, 0.788, 0.5, 0.7)
                }
            }

            // Lower target boundary guideline & edge marker
            Rectangle {
                id: lowGuideLine
                anchors.left: parent.left
                anchors.right: parent.right
                y: Math.round(targetBand.yLow)
                height: 1
                color: Qt.rgba(0, 0.788, 0.5, 0.35)
                visible: targetBand.range > 0 && targetBand.tLow <= usedChartMax && targetBand.tLow >= usedChartMin

                Label {
                    anchors.right: parent.right
                    anchors.top: parent.bottom
                    anchors.rightMargin: 4
                    anchors.topMargin: 1
                    text: units === Units.Unit.MMOL_L ? targetBand.tLow.toFixed(1) : targetBand.tLow.toString()
                    font.pointSize: 8
                    font.weight: Font.Medium
                    color: Qt.rgba(0, 0.788, 0.5, 0.7)
                }
            }
        }

        // ---- Line chart --------------------------------------------------
        Charts.LineChart {
            id: lineChart

            anchors {
                margins: Kirigami.Units.mediumSpacing
                left: yAxisLabels.right
                right: parent.right
                bottom: xAxisLabels.top
                top: headerBg.bottom
            }

            interpolate: true

            yRange {
                automatic: false
                from: usedChartMin
                to: usedChartMax
            }

            lineWidth: 3

            valueSources: Charts.ArraySource {
                array: valueSources
            }

            colorSource: Charts.SingleValueSource {
                value: Kirigami.Theme.highlightColor
            }

            pointDelegate: Item {
                width: 10
                height: 10

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: width / 2
                    color: lineChart.colorSource.value
                    border.color: Kirigami.Theme.backgroundColor
                    border.width: 2
                }
            }
        }

        ChartsControls.AxisLabels {
            id: xAxisLabels

            anchors {
                left: lineChart.left
                right: lineChart.right
                bottom: treatmentBar.top
                leftMargin: -Kirigami.Units.mediumSpacing
                rightMargin: -Kirigami.Units.mediumSpacing
                bottomMargin: Kirigami.Units.smallSpacing
            }

            delegate: Label {
                text: ChartsControls.AxisLabels.label
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: 9
            }

            source: Charts.ArraySource {
                array: labelSources
                wrap: false
            }
        }

        ChartsControls.AxisLabels {
            id: yAxisLabels

            direction: ChartsControls.AxisLabels.VerticalBottomTop

            anchors {
                left: parent.left
                leftMargin: Kirigami.Units.smallSpacing
                top: lineChart.top
                bottom: lineChart.bottom
            }

            delegate: Label {
                text: ChartsControls.AxisLabels.label
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: 9
                horizontalAlignment: Text.AlignRight
            }

            source: Charts.ChartAxisSource {
                chart: lineChart
                axis: Charts.ChartAxisSource.YAxis
                itemCount: 6
            }
        }

        ChartsControls.GridLines {
            id: horizontalLines

            anchors.fill: lineChart

            chart: lineChart

            direction: ChartsControls.GridLines.Horizontal

            major.count: 2
            major.lineWidth: 1
            major.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                 Kirigami.Theme.textColor.g,
                                 Kirigami.Theme.textColor.b, 0.15)

            minor.count: 5
            minor.lineWidth: 1
            minor.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                 Kirigami.Theme.textColor.g,
                                 Kirigami.Theme.textColor.b, 0.06)
        }

        ChartsControls.GridLines {
            id: verticalLines

            anchors.fill: lineChart

            chart: lineChart

            direction: ChartsControls.GridLines.Vertical

            major.count: 1
            major.lineWidth: 1
            major.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                 Kirigami.Theme.textColor.g,
                                 Kirigami.Theme.textColor.b, 0.15)

            minor.count: 4
            minor.lineWidth: 1
            minor.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                 Kirigami.Theme.textColor.g,
                                 Kirigami.Theme.textColor.b, 0.06)
        }

        // ---- Idle / error / offline overlay ------------------------------
        // Shown until the first poll completes, or when the widget is in an
        // error/offline state. Replaces the previous behavior where the chart
        // was simply blank with no explanation.
        Item {
            id: statusOverlay
            anchors.fill: lineChart
            visible: status !== "ok"

            Rectangle {
                anchors.fill: parent
                color: Kirigami.Theme.backgroundColor
                opacity: 0.6
            }

            Label {
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: 14
                font.weight: Font.Medium
                text: status === "idle" ? qsTr("Waiting for data…")
                      : status === "offline" ? qsTr("Offline — retrying")
                      : status === "error" ? qsTr("Error talking to Nightscout")
                      : ""
            }
        }

        // ---- Interactive hover inspection layer -------------------------
        Item {
            id: chartHoverOverlay
            anchors.fill: lineChart
            z: 20

            property int hoveredIndex: -1
            readonly property bool hasValidData: root.valueSources && root.valueSources.length > 1
            readonly property real hoveredVal: (hasValidData && hoveredIndex >= 0 && hoveredIndex < root.valueSources.length) ? root.valueSources[hoveredIndex] : 0
            readonly property var hoveredTs: (hasValidData && hoveredIndex >= 0 && root.chartTimestamps && hoveredIndex < root.chartTimestamps.length) ? root.chartTimestamps[hoveredIndex] : 0
            readonly property real chartRange: root.usedChartMax - root.usedChartMin
            readonly property real snappedX: (hasValidData && hoveredIndex >= 0) ? (hoveredIndex / (root.valueSources.length - 1)) * width : 0
            readonly property real snappedY: (chartRange > 0 && hoveredIndex >= 0) ? ((root.usedChartMax - hoveredVal) / chartRange) * height : 0

            visible: hoverMouseArea.containsMouse && hoveredIndex >= 0 && !isNaN(hoveredVal) && status === "ok"

            // Crosshair vertical hairline
            Rectangle {
                x: Math.round(chartHoverOverlay.snappedX)
                y: 0
                width: 1
                height: parent.height
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.22)
            }

            // Glowing indicator dot
            Rectangle {
                x: Math.round(chartHoverOverlay.snappedX - width / 2)
                y: Math.round(chartHoverOverlay.snappedY - height / 2)
                width: 16
                height: 16
                radius: 8
                color: Units.isInGreenRange(chartHoverOverlay.hoveredVal, units)
                       ? Qt.rgba(0, 0.788, 0.5, 0.25)
                       : Qt.rgba(Kirigami.Theme.highlightColor.r,
                                 Kirigami.Theme.highlightColor.g,
                                 Kirigami.Theme.highlightColor.b, 0.25)

                Rectangle {
                    anchors.centerIn: parent
                    width: 8
                    height: 8
                    radius: 4
                    color: Units.isInGreenRange(chartHoverOverlay.hoveredVal, units)
                           ? "#00c950"
                           : Kirigami.Theme.highlightColor
                    border.color: Kirigami.Theme.backgroundColor
                    border.width: 1.5
                }
            }

            // Floating inspection tooltip
            Rectangle {
                id: hoverTooltip
                property real targetX: chartHoverOverlay.snappedX - width / 2
                property real clampedX: Math.max(4, Math.min(parent.width - width - 4, targetX))
                property bool showBelow: chartHoverOverlay.snappedY < 50
                x: clampedX
                y: showBelow ? Math.min(parent.height - height - 4, chartHoverOverlay.snappedY + 12)
                             : Math.max(4, chartHoverOverlay.snappedY - height - 12)
                width: tooltipLayout.implicitWidth + 16
                height: tooltipLayout.implicitHeight + 8
                radius: 6
                color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                               Kirigami.Theme.backgroundColor.g,
                               Kirigami.Theme.backgroundColor.b, 0.94)
                border.color: Qt.rgba(Kirigami.Theme.textColor.r,
                                      Kirigami.Theme.textColor.g,
                                      Kirigami.Theme.textColor.b, 0.18)
                border.width: 1

                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: Qt.rgba(0, 0, 0, 0.35)
                    shadowBlur: 0.3
                    shadowVerticalOffset: 2
                }

                RowLayout {
                    id: tooltipLayout
                    anchors.centerIn: parent
                    spacing: 6

                    Label {
                        text: chartHoverOverlay.hoveredTs > 0 ? Qt.formatTime(new Date(chartHoverOverlay.hoveredTs), "hh:mm") : ""
                        font.pointSize: 9
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: Kirigami.Theme.disabledTextColor
                    }

                    Label {
                        text: (units === Units.Unit.MMOL_L ? chartHoverOverlay.hoveredVal.toFixed(1) : Math.round(chartHoverOverlay.hoveredVal).toString()) + " " + Units.getUnitText(units)
                        font.pointSize: 10
                        font.weight: Font.Bold
                        color: Units.isInGreenRange(chartHoverOverlay.hoveredVal, units)
                               ? "#00c950"
                               : Kirigami.Theme.textColor
                    }
                }
            }

            MouseArea {
                id: hoverMouseArea
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.NoButton
                onPositionChanged: (mouse) => {
                    if (!chartHoverOverlay.hasValidData) {
                        chartHoverOverlay.hoveredIndex = -1;
                        return;
                    }
                    var count = root.valueSources.length;
                    var fraction = Math.max(0, Math.min(1, mouse.x / width));
                    var idx = Math.round(fraction * (count - 1));
                    if (idx >= 0 && idx < count && !isNaN(root.valueSources[idx])) {
                        chartHoverOverlay.hoveredIndex = idx;
                    } else {
                        chartHoverOverlay.hoveredIndex = -1;
                    }
                }
                onExited: chartHoverOverlay.hoveredIndex = -1
            }
        }

        // ---- Treatment indicators overlay --------------------------------
        //
        // Coordinate-system note: Charts.LineChart plots entries at evenly
        // spaced x positions by *array index*, not by timestamp. So the
        // treatment overlay must map each treatment's timestamp to a
        // fractional entry index (`timestampToFractionalIndex`), then map
        // that index to pixel x the same way the chart would
        // (`index / (count - 1) * width`). The earlier approach mapped
        // timestamps directly to a [visibleStart, visibleEnd] range and was
        // wrong for two reasons: (1) it assumed the chart's right edge
        // represented "now", which it doesn't, and (2) it ignored the
        // non-uniform time spacing between consecutive readings (sensor
        // gaps). The result was treatments rendered in the wrong place,
        // especially recent ones near the right edge.
        Item {
            id: treatmentOverlay
            anchors.fill: lineChart
            clip: true

            // 5-minute bucket width in ms. Treatments within the same bucket
            // get stacked vertically on distinct rows.
            readonly property int bucketMs: 5 * 60 * 1000
            // Row pitch in pixels. Each stacked treatment occupies this much
            // vertical space below the previous one.
            readonly property int rowPitch: 22
            // Clock-time cutoff after which a treatment is considered off the
            // right edge. We include a few minutes of slack past the last
            // reading so a brand-new treatment still satisfies the visibility
            // predicate while its dot is rendered via the extrapolation path
            // in timestampToFractionalIndex.
            readonly property var visibleEndClock: {
                if (root.chartTimeEnd > 0) {
                    return Math.max(root.chartTimeEnd, Date.now()) + 5 * 60 * 1000;
                }
                return 0;
            }

            property var sortedTreatments: []
            property var bucketAssignments: ({})

            onWidthChanged: recomputeBuckets()

            // `treatments` lives on the PlasmoidItem root (main.qml); use a
            // Connections object so we react to its change signal without
            // relying on lexical scope for property-change handler resolution.
            // We call both recomputes from a single handler so we don't have to
            // register two separate Connections blocks.
            Connections {
                target: root
                function onTreatmentsChanged() {
                    treatmentOverlay.recomputeBuckets();
                    treatmentOverlay.scheduleTick();
                }
                function onChartTimestampsChanged() {
                    treatmentOverlay.recomputeBuckets();
                    treatmentOverlay.scheduleTick();
                }
            }

            function recomputeBuckets() {
                var src = root.treatments;
                if (!src || src.length === 0) {
                    sortedTreatments = [];
                    bucketAssignments = ({});
                    return;
                }
                var sorted = src.slice().sort(function (a, b) {
                    return Treatments.timestampFor(a) - Treatments.timestampFor(b);
                });
                var w = treatmentOverlay.width > 0 ? treatmentOverlay.width : (diagramRoot.width > 0 ? diagramRoot.width : 600);
                var assignments = ({});
                var rowLastX = [];
                var minClearance = 115;

                for (var i = 0; i < sorted.length; i++) {
                    var t = sorted[i];
                    var ts = Treatments.timestampFor(t);
                    var x = treatmentOverlay.timestampToPixelX(ts, w);

                    var assignedRow = 0;
                    var found = false;
                    for (var r = 0; r < rowLastX.length; r++) {
                        if (x >= rowLastX[r] + minClearance) {
                            assignedRow = r;
                            rowLastX[r] = x;
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        assignedRow = rowLastX.length;
                        rowLastX.push(x);
                    }
                    assignments[i] = assignedRow;
                }
                sortedTreatments = sorted;
                bucketAssignments = assignments;
            }

            // Per-pixel x for a delegate. We compute the fractional entry
            // index in the shared, tested `treatments.js` helper and then
            // scale it to chart width matching Charts.LineChart's plot geometry.
            function timestampToPixelX(ts, width) {
                var ct = root.chartTimestamps;
                if (!ct || ct.length < 2) return 0;
                var fr = Treatments.timestampToFractionalIndex(ct, ts);
                return (fr / (ct.length - 1)) * width;
            }

            // Single self-scheduling tick used to keep every delegate's
            // `timeAgo` label and visibility aligned with the wall clock.
            //
            // We pick the soonest "next minute boundary" across the rendered
            // delegates (treatments whose timestamp sits inside the chart's
            // visible window) and schedule a single one-shot at that exact
            // moment. That way we get minute-resolution accuracy without
            // running a wasteful per-second heartbeat. A new scheduling
            // recompute is triggered any time the treatments list, the chart
            // timestamp list, or the widget's visibility changes; otherwise
            // the timer just fires once and re-arms itself.
            property int tickCount: 0
            Timer {
                id: tickTimer
                interval: 60000
                repeat: false
                running: false
                onTriggered: {
                    treatmentOverlay.tickCount++;
                    treatmentOverlay.scheduleTick();
                }
            }

            function scheduleTick() {
                var src = sortedTreatments;
                if (!src || src.length === 0) { tickTimer.stop(); return; }
                var now = Date.now();
                var ct = root.chartTimestamps;
                if (!ct || ct.length < 2) { tickTimer.stop(); return; }
                var lo = ct[0], hi = ct[ct.length - 1];
                var nextMs = -1;
                for (var i = 0; i < src.length; i++) {
                    var ts = Treatments.timestampFor(src[i]);
                    // Only schedule ticks for treatments still inside the
                    // chart's expanded visible window.
                    if (ts <= 0 || ts < lo || ts > visibleEndClock) continue;
                    // Time until the "m ago" value flips to (tot + 1) minutes:
                    // that's the first instant strictly after now whose
                    // floor((now - ts)/60000) is one greater than at `now`.
                    var elapsed = now - ts;
                    var totalMin = Math.floor(elapsed / 60000);
                    var msUntilNextMin = 60000 - (elapsed - totalMin * 60000);
                    // Skip treatments already at the next minute when `now`
                    // is past a boundary by a tiny amount (defensive).
                    if (msUntilNextMin <= 0) msUntilNextMin = 1;
                    if (nextMs < 0 || msUntilNextMin < nextMs) nextMs = msUntilNextMin;
                }
                if (nextMs < 0 || !diagramRoot.visible) {
                    tickTimer.stop();
                    return;
                }
                tickTimer.interval = Math.max(1, nextMs);
                tickTimer.restart();
            }

            // Recompute bucketing and reschedule the time-ago timer when the
            // widget is first realized or becomes visible (e.g. the user
            // expanded it from the compact representation). Connections
            // handlers cover the data-change case; this catches the
            // visibility case.
            Component.onCompleted: {
                recomputeBuckets();
                scheduleTick();
            }
            onVisibleChanged: if (visible) {
                recomputeBuckets();
                scheduleTick();
            }

            Repeater {
                model: treatmentOverlay.sortedTreatments

                delegate: Item {
                    id: delegateRoot

                    // Index in the sorted array, used as a key for the bucket
                    // assignment map.
                    required property int index
                    // modelData is the treatment object from the sorted array.
                    required property var modelData

                    property var treatment: modelData
                    property var timestamp: Treatments.timestampFor(treatment)
                    readonly property color treatmentColor: Treatments.colorFor(delegateRoot.treatment)

                    // x position of the dot's CENTER, in chart index-space.
                    // Dot is anchored to this exact x; labels are anchored
                    // relative to the dot, so widening a label never shifts
                    // the dot off its time slot.
                    //
                    // `tickCount` is read here so QML re-evaluates `xPos`
                    // every minute boundary. The position of a treatment
                    // relative to the chart's right edge depends on "now",
                    // and the entry/extrapolation interpolation for a fresh
                    // treatment changes between tickCount updates.
                    property real xPos: {
                        treatmentOverlay.tickCount; // bind dep
                        return treatmentOverlay.timestampToPixelX(timestamp, parent.width);
                    }

                    // Re-derive visibility from the chart's time bounds so a
                    // treatment outside the visible window is hidden even
                    // when timestampToPixelX still returns a value. Reading
                    // `tickCount` keeps this in sync with the wall clock so
                    // a treatment that should age out of the right-edge
                    // window between data polls is hidden at the right
                    // moment, not on the next 5-minute poll.
                    visible: {
                        treatmentOverlay.tickCount; // bind dep
                        return timestamp > 0
                               && root.chartTimestamps
                               && root.chartTimestamps.length >= 2
                               && timestamp >= root.chartTimeStart
                               && timestamp <= treatmentOverlay.visibleEndClock;
                    }

                    // Vertical row within the bucket. Hover pops the delegate
                    // to the front so its label is never covered by a sibling.
                    property int row: treatmentOverlay.bucketAssignments[index] || 0
                    property real yBase: 2 + row * treatmentOverlay.rowPitch
                    // timeAgoText must depend on treatmentOverlay.tickCount
                    // so QML re-evaluates the binding every time the
                    // self-scheduling timer (see treatmentOverlay above)
                    // fires at the next minute boundary.
                    property string timeAgoText: {
                        treatmentOverlay.tickCount; // bind dep
                        return Format.timeAgo(timestamp);
                    }
                    property bool hovered: false

                    // Position delegate horizontally so pill is centered over xPos,
                    // clamped within bounds of the treatment overlay.
                    x: Math.max(0, Math.min(treatmentOverlay.width - width, Math.round(xPos - width / 2)))
                    y: yBase
                    z: hovered ? 100 : 1

                    width: pill.width
                    height: pill.height

                    // Subtle vertical drop guideline from the bottom of the pill
                    // down to the timeline axis at xPos.
                    Rectangle {
                        id: dropGuideline
                        x: Math.round(delegateRoot.xPos - delegateRoot.x)
                        y: pill.height
                        width: 1
                        height: Math.max(0, treatmentOverlay.height - delegateRoot.y - pill.height)
                        color: delegateRoot.treatmentColor
                        opacity: delegateRoot.hovered ? 0.5 : 0.18
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }

                    // Frosted pill badge
                    Rectangle {
                        id: pill
                        width: pillLayout.implicitWidth + 12
                        height: 18
                        radius: 9
                        color: Qt.rgba(Kirigami.Theme.backgroundColor.r,
                                       Kirigami.Theme.backgroundColor.g,
                                       Kirigami.Theme.backgroundColor.b,
                                       delegateRoot.hovered ? 0.96 : 0.82)
                        border.color: delegateRoot.hovered
                                      ? delegateRoot.treatmentColor
                                      : Qt.rgba(delegateRoot.treatmentColor.r,
                                                delegateRoot.treatmentColor.g,
                                                delegateRoot.treatmentColor.b, 0.4)
                        border.width: 1
                        scale: delegateRoot.hovered ? 1.05 : 1.0
                        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                        Behavior on border.color { ColorAnimation { duration: 120 } }

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            shadowEnabled: delegateRoot.hovered
                            shadowColor: Qt.rgba(0, 0, 0, 0.3)
                            shadowBlur: 0.2
                            shadowVerticalOffset: 1
                        }

                        RowLayout {
                            id: pillLayout
                            anchors.centerIn: parent
                            spacing: 4

                            Rectangle {
                                width: 6
                                height: 6
                                radius: 3
                                color: delegateRoot.treatmentColor
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                text: Treatments.labelFor(delegateRoot.treatment)
                                color: Kirigami.Theme.textColor
                                font.pointSize: 8
                                font.weight: Font.DemiBold
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                text: "·"
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: 7
                                Layout.alignment: Qt.AlignVCenter
                            }

                            Label {
                                text: delegateRoot.timeAgoText
                                color: Kirigami.Theme.disabledTextColor
                                font.pointSize: 8
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: pill
                        hoverEnabled: true
                        onEntered: delegateRoot.hovered = true
                        onExited: delegateRoot.hovered = false
                        propagateComposedEvents: true
                    }
                }
            }
        }

        // ---- Treatment bar (add new entry) -------------------------------
        Item {
            id: treatmentBar
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: Kirigami.Units.gridUnit * 3

            property string selectedType: "carbs"
            property int valueFontSize: Math.round(Kirigami.Units.gridUnit * 0.7)

            // Hardcoded treatment type list replaced with the single source
            // of truth in lib/treatments.js so colors/labels cannot drift.
            function cycleType(direction) {
                var types = Treatments.TYPES.map(function (t) { return t.key; });
                var idx = types.indexOf(selectedType);
                if (idx < 0) idx = 0;
                idx = (idx + direction + types.length) % types.length;
                selectedType = types[idx];
            }

            Component.onCompleted: {
                var initial = root.lastSelectedType;
                if (initial === "humalog") initial = "admelog";
                selectedType = initial;
            }

            onSelectedTypeChanged: {
                root.lastSelectedType = selectedType;
                Qt.callLater(function() { valueInput.forceActiveFocus(); });
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.06)
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.rgba(Kirigami.Theme.textColor.r,
                               Kirigami.Theme.textColor.g,
                               Kirigami.Theme.textColor.b, 0.12)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Kirigami.Units.largeSpacing
                anchors.rightMargin: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing

                Repeater {
                    model: Treatments.TYPES

                    delegate: Button {
                        id: typeBtn
                        required property var modelData
                        text: modelData.label
                        checkable: true
                        checked: treatmentBar.selectedType === modelData.key
                        onClicked: treatmentBar.selectedType = modelData.key
                        Layout.minimumWidth: 76
                        Layout.fillHeight: true
                        leftPadding: 12
                        rightPadding: 12
                        topPadding: 8
                        bottomPadding: 8

                        readonly property color accentColor: modelData.accent

                        Keys.onLeftPressed: (event) => { treatmentBar.cycleType(-1); event.accepted = true; }
                        Keys.onRightPressed: (event) => { treatmentBar.cycleType(1); event.accepted = true; }

                        background: Rectangle {
                            color: typeBtn.checked ? typeBtn.accentColor
                                  : typeBtn.down ? Qt.rgba(1, 1, 1, 0.12)
                                  : Qt.rgba(1, 1, 1, 0.04)
                            border.color: typeBtn.checked ? "transparent" : typeBtn.accentColor
                            border.width: typeBtn.checked ? 0 : 1
                            radius: 8
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }
                        contentItem: Text {
                            text: typeBtn.text
                            color: typeBtn.checked ? "white" : typeBtn.accentColor
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            font.pointSize: 10
                            font.weight: typeBtn.checked ? Font.Bold : Font.Medium
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                TextField {
                    id: valueInput
                    placeholderText: treatmentBar.selectedType === "carbs" ? qsTr("grams") : qsTr("units")
                    validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
                    Layout.preferredWidth: 90
                    Layout.fillHeight: true
                    font.pointSize: treatmentBar.valueFontSize
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 10
                    rightPadding: 10

                    Keys.onLeftPressed: (event) => { treatmentBar.cycleType(-1); event.accepted = true; }
                    Keys.onRightPressed: (event) => { treatmentBar.cycleType(1); event.accepted = true; }
                    Keys.onReturnPressed: (event) => { addBtn.clicked(); event.accepted = true; }
                    Keys.onEnterPressed: (event) => { addBtn.clicked(); event.accepted = true; }
                }

                TextField {
                    id: timeInput
                    placeholderText: qsTr("HH:MM")
                    font.pointSize: treatmentBar.valueFontSize
                    Layout.preferredWidth: 85
                    Layout.fillHeight: true
                    maximumLength: 5
                    selectByMouse: true
                    verticalAlignment: TextInput.AlignVCenter
                    leftPadding: 10
                    rightPadding: 10

                    // Strict HH:MM (0-23 / 00-59) so "999:99" and "1:5" are
                    // rejected rather than silently coerced.
                    validator: RegularExpressionValidator { regularExpression: /^(0?\d|1\d|2[0-3]):[0-5]\d$/ }

                    Keys.onLeftPressed: (event) => { treatmentBar.cycleType(-1); event.accepted = true; }
                    Keys.onRightPressed: (event) => { treatmentBar.cycleType(1); event.accepted = true; }
                    Keys.onReturnPressed: (event) => { addBtn.clicked(); event.accepted = true; }
                    Keys.onEnterPressed: (event) => { addBtn.clicked(); event.accepted = true; }
                }

                Button {
                    id: addBtn
                    text: qsTr("Add")
                    property bool isSubmitting: false
                    enabled: !isSubmitting && valueInput.text.length > 0 && !isNaN(parseValue()) && (timeInput.text.length === 0 || timeInput.acceptableInput)
                    Layout.minimumWidth: 64
                    Layout.fillHeight: true
                    leftPadding: 14
                    rightPadding: 14

                    readonly property color typeColor: Treatments.typeByKey(treatmentBar.selectedType).accent

                    background: Rectangle {
                        radius: 8
                        opacity: addBtn.enabled ? 1.0 : 0.4
                        color: addBtn.enabled ? addBtn.typeColor : Kirigami.Theme.disabledTextColor
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                    contentItem: Text {
                        text: addBtn.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        font.pointSize: 10
                        font.weight: Font.Bold
                    }

                    // Local-aware number parse for DoubleValidator with locale
                    // "C" above, parseFloat now uses the dot decimal separator
                    // reliably. Carbs are an integer (grams).
                    function parseValue() {
                        var typeKey = treatmentBar.selectedType;
                        var text = valueInput.text.replace(',', '.');
                        var value = parseFloat(text);
                        if (isNaN(value) || value <= 0) return NaN;
                        if (typeKey === "carbs") {
                            if (value > 500) return NaN;
                            return Math.round(value);
                        }
                        if (value > 150) return NaN;
                        return value;
                    }

                    onClicked: {
                        if (!enabled) return;

                        var value = parseValue();
                        if (isNaN(value)) return;

                        if (timeInput.text.length > 0 && !timeInput.acceptableInput) return;

                        isSubmitting = true;

                        var dateObj = new Date();
                        if (timeInput.text.length >= 4 && timeInput.text.indexOf(":") > 0) {
                            var parts = timeInput.text.split(":");
                            dateObj.setHours(parseInt(parts[0], 10), parseInt(parts[1] || "0", 10), 0, 0);
                            if (dateObj.getTime() > Date.now() + 60000) {
                                dateObj.setDate(dateObj.getDate() - 1);
                            }
                        }

                        var url = Api.postTreatmentUrl(root.sanitizedNightscoutURL, root.nightscoutToken);
                        var payload = Treatments.buildPayload(treatmentBar.selectedType, value, dateObj);

                        Api.post(url, payload, function (response) {
                            addBtn.isSubmitting = false;
                            if (response.status < 300) {
                                valueInput.text = "";
                                timeInput.text = "";
                                Qt.callLater(function() { valueInput.forceActiveFocus(); });
                                root.reloadChart();
                            } else {
                                console.warn("nightscout: treatment POST failed:", response.status, response.error);
                            }
                        });
                    }
                }
            }
        }
    }
}
