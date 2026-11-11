import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

Item {
    id: rootWidget

    // Panel height used to compute automatic sizing.
    readonly property int panelHeight: Math.max(rootWidget.height, 16)
    readonly property int autoRingSize: Math.min(panelHeight, 24)
    readonly property int autoLabelSize: Math.max(10, Math.round(panelHeight * 0.99))

    readonly property bool showRing: root.showPollRing !== undefined ? root.showPollRing : true
    readonly property int ringSize: (root.autoRingSize !== undefined && root.autoRingSize) ? autoRingSize : Math.max(8, (root.customRingSize || 24))
    readonly property int labelSize: (root.autoFontSize !== undefined && root.autoFontSize) ? autoLabelSize : Math.max(6, (root.customFontSize || 14))
    readonly property int trendSize: (root.matchTrendSize !== undefined && root.matchTrendSize) ? labelSize : Math.max(6, (root.customTrendSize || 14))
    readonly property bool isBold: root.boldText !== undefined ? root.boldText : true
    readonly property int spacing: root.itemSpacing !== undefined ? root.itemSpacing : 4
    readonly property int hMargin: root.horizontalMargin !== undefined ? root.horizontalMargin : 2

    Layout.preferredWidth: {
        var w = 2 * hMargin;
        var count = 0;
        if (showRing) {
            w += ringSize;
            count++;
        }
        w += glucoseLabel.implicitWidth;
        count++;
        w += trendLabel.implicitWidth;
        count++;
        if (count > 1) {
            w += (count - 1) * spacing;
        }
        return Math.ceil(w);
    }
    Layout.preferredHeight: Math.max(showRing ? ringSize : 0, glucoseLabel.implicitHeight, trendLabel.implicitHeight)

    RowLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: rootWidget.hMargin
        anchors.rightMargin: rootWidget.hMargin
        anchors.verticalCenter: parent.verticalCenter
        spacing: rootWidget.spacing

        Canvas {
            id: pollRing
            visible: rootWidget.showRing
            Layout.preferredWidth: rootWidget.ringSize
            Layout.preferredHeight: rootWidget.ringSize
            Layout.alignment: Qt.AlignVCenter

            property real progress: root.pollProgress

            onProgressChanged: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var strokeW = Math.max(1.5, Math.min(6, width / 7));
                var r = Math.max(1, width / 2 - strokeW / 2 - 0.5);
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = Qt.rgba(0.443, 0.878, 0.957, 0.1);
                ctx.lineWidth = strokeW;
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress);
                ctx.strokeStyle = Qt.rgba(0.443, 0.878, 0.957, 1);
                ctx.lineWidth = strokeW;
                ctx.lineCap = "round";
                ctx.stroke();
            }

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Label {
            id: glucoseLabel
            text: root.glucose
            color: root.isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : root.glucoseColor
            font.pointSize: rootWidget.labelSize
            font.bold: rootWidget.isBold
            Layout.alignment: Qt.AlignVCenter

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }

        Label {
            id: trendLabel
            text: root.trend
            color: root.isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : root.glucoseColor
            font.pointSize: rootWidget.trendSize
            font.bold: rootWidget.isBold
            Layout.alignment: Qt.AlignVCenter

            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: "black"
                shadowBlur: 0.5
                shadowHorizontalOffset: 0
                shadowVerticalOffset: 0
            }
        }
    }

    // Simple expand/collapse toggle.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (mouse) => { root.expanded = !root.expanded; mouse.accepted = true }
    }
}
