import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kquickcontrolsaddons
import org.kde.plasma.components

Item {
    id: rootWidget

    // All intrinsic sizes derive from the panel-provided height so the widget
    // looks right both in short panels (e.g. 24-28px) and tall ones, instead of
    // the previous hard-coded 24pt fonts and 24px ring that overflowed a
    // short panel and looked tiny in a tall one.
    readonly property int panelHeight: Math.max(rootWidget.height, 16)
    readonly property int ringSize: Math.min(panelHeight, 24)
    readonly property int labelSize: Math.max(10, Math.round(panelHeight * 0.99))

    Layout.preferredWidth: pollRing.width + Kirigami.Units.smallSpacing + glucoseLabel.implicitWidth + 2 + trendLabel.implicitWidth
    Layout.preferredHeight: Math.max(glucoseLabel.implicitHeight, trendLabel.implicitHeight, pollRing.height)

    Item {
        anchors.fill: parent

        Canvas {
            id: pollRing
            width: rootWidget.ringSize
            height: rootWidget.ringSize
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter

            property real progress: pollProgress

            onProgressChanged: requestPaint()
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var cx = width / 2;
                var cy = height / 2;
                var r = width / 2 - 2;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                ctx.strokeStyle = Qt.rgba(0.443, 0.878, 0.957, 0.1);
                ctx.lineWidth = 3;
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * progress);
                ctx.strokeStyle = Qt.rgba(0.443, 0.878, 0.957, 1);
                ctx.lineWidth = 3;
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
            text: glucose
            color: isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : glucoseColor
            font.pointSize: rootWidget.labelSize
            font.bold: true
            anchors.left: pollRing.right
            anchors.leftMargin: Kirigami.Units.smallSpacing
            anchors.verticalCenter: parent.verticalCenter

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
            text: trend
            color: isStale ? Qt.rgba(0.6, 0.6, 0.6, 0.8) : glucoseColor
            font.pointSize: rootWidget.labelSize
            font.bold: true
            anchors.left: glucoseLabel.right
            anchors.leftMargin: 2
            anchors.verticalCenter: parent.verticalCenter

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

    // Simple expand/collapse toggle. Removed the previously tracked
    // `wasExpanded` property because PlasmoidItem.expanded is already an
    // idempotent toggle here, and the manual tracking could desync on a
    // drag-then-click.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: (mouse) => { root.expanded = !root.expanded; mouse.accepted = true }
    }
}
