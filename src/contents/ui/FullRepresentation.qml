import QtQuick
import QtQuick.Layouts
import org.kde.quickcharts as Charts
import org.kde.quickcharts.controls
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kquickcontrolsaddons
import org.kde.plasma.components
import org.kde.quickcharts.controls as ChartsControls
import "../lib/utils.js" as Utils

ColumnLayout {
    id: diagramRoot

    anchors.fill: parent

    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 650

        ColumnLayout {
            id: headerLayout

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
            }

            Label {
                id: currentBG
                text: glucose + " " + trend
                color: glucoseColor

                Layout.fillWidth: true

                font.pointSize: 48
                font.bold: true

                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }

            Label {
                text: timeAgo
                Layout.fillWidth: true
                font.pointSize: 10
                font.bold: true
                opacity: 0.7
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }

        Charts.LineChart {
            id: lineChart

            anchors {
                margins: Kirigami.Units.mediumSpacing
                left: yAxisLabels.right
                right: parent.right
                bottom: xAxisLabels.top
                top: headerLayout.bottom
            }
            
            interpolate: false

            yRange {
                automatic: false
                from: usedChartMin
                to: usedChartMax
            }

            lineWidth: 0

            valueSources: Charts.ArraySource {
                array: valueSources
            }

            colorSource: Charts.SingleValueSource {
                value: Kirigami.Theme.highlightColor
            }

            pointDelegate: Item {
                width: 8
                height: 8

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: parent.height
                    radius: width / 2
                    
                    color: lineChart.colorSource.value 
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
            }

            delegate: Label {
                text: ChartsControls.AxisLabels.label
            }

            source: Charts.ArraySource {
                array: labelSources
                wrap: false
            }
        }

        ChartsControls.AxisLabels {
            id: yAxisLabels

            direction: AxisLabels.VerticalBottomTop

            anchors {
                left: parent.left
                top: lineChart.top
                bottom: lineChart.bottom
            }

            delegate: Label {
                text: ChartsControls.AxisLabels.label
            }

            source: Charts.ChartAxisSource {
                chart: lineChart
                axis: Charts.ChartAxisSource.YAxis
                itemCount: 6
            }
        }

        GridLines {
            id: horizontalLines

            anchors.fill: lineChart

            chart: lineChart

            direction: GridLines.Horizontal

            major.count: 2
            major.lineWidth: 2
            major.color: Qt.rgba(0.8, 0.8, 0.8, 0)

            minor.count: 5
            minor.lineWidth: 1
            minor.color: Qt.rgba(0.8, 0.8, 0.8, 0.2)
        }

        GridLines {
            id: verticalLines

            anchors.fill: lineChart

            chart: lineChart

            direction: GridLines.Vertical

            major.count: 1
            major.lineWidth: 2
            major.color: Qt.rgba(0.8, 0.8, 0.8, 0)

            minor.count: 4
            minor.lineWidth: 1
            minor.color: Qt.rgba(0.8, 0.8, 0.8, 0.2)
        }

        // Treatment indicators overlay
        Item {
            id: treatmentOverlay
            anchors.fill: lineChart
            anchors.margins: Kirigami.Units.mediumSpacing
            clip: true

            property int agoTick: 0
            Timer {
                interval: 10000
                repeat: true
                running: true
                onTriggered: agoTick++
            }

            function treatmentColor(t) {
                if (t.carbs) {
                    if (t.insulin) return "#8e44ad";
                    return "#f97316";
                }
                if (t.insulinInjections) {
                    try {
                        var injections = JSON.parse(t.insulinInjections);
                        if (injections.length > 0 && injections[0].insulin === "Humalog") return "#ec4899";
                    } catch(e) {}
                }
                if (t.insulin) return "#3b82f6";
                return "#95a5a6";
            }

            function treatmentLabel(t) {
                var parts = [];
                if (t.carbs) parts.push(Math.round(t.carbs) + "g");
                if (t.insulin) parts.push(parseFloat(t.insulin).toFixed(1) + "u");
                if (parts.length === 0 && t.notes) parts.push(t.notes);
                return parts.join(" ");
            }

            function treatmentTimestamp(t) {
                if (t.date) return t.date;
                if (t.created_at) return new Date(t.created_at).getTime();
                return 0;
            }

            Repeater {
                model: treatments

                delegate: Item {
                    visible: timestamp > 0 && chartTimeEnd > chartTimeStart && timestamp >= chartTimeStart && timestamp <= chartTimeEnd

                    property var treatment: modelData
                    property var timestamp: treatmentOverlay.treatmentTimestamp(treatment)
                    property real xPos: (timestamp - chartTimeStart) / (chartTimeEnd - chartTimeStart) * parent.width
                    property string timeAgoText: treatmentOverlay.agoTick >= 0 ? Math.floor((Date.now() - timestamp) / 60000) + "m ago" : ""

                    x: xPos - width / 2
                    y: 2

                    width: Math.max(dotLabelRow.width, timeLabel.implicitWidth)
                    height: dotLabelRow.height + timeLabel.implicitHeight

                    Row {
                        id: dotLabelRow
                        spacing: 3

                        Rectangle {
                            id: dot
                            width: 8
                            height: 8
                            radius: width / 2
                            color: treatmentOverlay.treatmentColor(treatment)
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Label {
                            id: valueLabel
                            text: treatmentOverlay.treatmentLabel(treatment)
                            color: "white"
                            font.pointSize: 10
                            opacity: 0.85
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Label {
                        id: timeLabel
                        text: timeAgoText
                        color: "white"
                        font.pointSize: 9
                        opacity: 0.6
                        anchors.horizontalCenter: dot.horizontalCenter
                        anchors.top: dotLabelRow.bottom
                        anchors.topMargin: 1
                    }
                }
            }
        }

        // Treatment bar
        Item {
            id: treatmentBar
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
            }
            height: 52

            property string selectedType: "carbs"
            property int valueFontSize: 12

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: 1
                color: Qt.rgba(1, 1, 1, 0.15)
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 5

                Button {
                    id: carbsBtn
                    text: "Carbs"
                    checkable: true
                    checked: treatmentBar.selectedType === "carbs"
                    onClicked: treatmentBar.selectedType = "carbs"
                    Layout.minimumWidth: 60
                }

                Button {
                    id: humalogBtn
                    text: "Humalog"
                    checkable: true
                    checked: treatmentBar.selectedType === "humalog"
                    onClicked: treatmentBar.selectedType = "humalog"
                    Layout.minimumWidth: 60
                }

                Button {
                    id: tresibaBtn
                    text: "Tresiba"
                    checkable: true
                    checked: treatmentBar.selectedType === "tresiba"
                    onClicked: treatmentBar.selectedType = "tresiba"
                    Layout.minimumWidth: 60
                }

                TextField {
                    id: valueInput
                    placeholderText: treatmentBar.selectedType === "carbs" ? "grams" : "units"
                    validator: DoubleValidator { bottom: 0 }
                    Layout.preferredWidth: 70
                    font.pointSize: treatmentBar.valueFontSize
                }

                TextField {
                    id: timeInput
                    placeholderText: "HH:MM"
                    font.pointSize: treatmentBar.valueFontSize
                    Layout.preferredWidth: 60
                    maximumLength: 5
                }

                Button {
                    id: addBtn
                    text: "Add"
                    enabled: valueInput.text.length > 0
                    onClicked: {
                        if (valueInput.text.length === 0) return;
                        addBtn.enabled = false;

                        var value = parseFloat(valueInput.text);
                        var dateObj = new Date();
                        if (timeInput.text.length >= 4 && timeInput.text.indexOf(":") > 0) {
                            var parts = timeInput.text.split(":");
                            dateObj.setHours(parseInt(parts[0]), parseInt(parts[1] || "0"), 0, 0);
                        }

                        var createdAt = dateObj.toISOString();
                        var url = sanitizedNightscoutURL + "/api/v1/treatments?token=" + nightscoutToken;

                        if (treatmentBar.selectedType === "carbs") {
                            Utils.sendJsonPost(url, {
                                eventType: "Carb Correction",
                                carbs: value,
                                enteredBy: "Nightscout Widget",
                                created_at: createdAt
                            }, function(response) {
                                addBtn.enabled = true;
                                if (response.status < 300) {
                                    valueInput.text = "";
                                    timeInput.text = "";
                                    readData();
                                }
                            });
                        } else {
                            var insulinName = treatmentBar.selectedType === "humalog" ? "Humalog" : "tresiba";
                            Utils.sendJsonPost(url, {
                                eventType: "Correction Bolus",
                                insulin: value,
                                enteredBy: "Nightscout Widget",
                                created_at: createdAt,
                                insulinInjections: JSON.stringify([{ insulin: insulinName, units: value }])
                            }, function(response) {
                                addBtn.enabled = true;
                                if (response.status < 300) {
                                    valueInput.text = "";
                                    timeInput.text = "";
                                    readData();
                                }
                            });
                        }
                    }
                }
            }
        }
    }
}
