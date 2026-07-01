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
    
    Layout.preferredWidth: pollRing.width + 4 + glucoseLabel.implicitWidth + 2 + trendLabel.implicitWidth
    Layout.preferredHeight: Math.max(glucoseLabel.implicitHeight, trendLabel.implicitHeight, pollRing.height)

    Item {
        anchors.fill: parent

        Canvas {
            id: pollRing
            width: 24
            height: 24
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
            color: glucoseColor
            font.pointSize: 24
            font.bold: true
            anchors.left: pollRing.right
            anchors.leftMargin: 6
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
            color: glucoseColor
            font.pointSize: 24
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

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true

        property bool wasExpanded: false
        onPressed: wasExpanded = root.expanded
        onClicked: mouse => {
            root.expanded = !wasExpanded;
        }
    }
}