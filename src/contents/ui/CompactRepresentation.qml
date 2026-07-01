import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kquickcontrolsaddons
import org.kde.plasma.components

Item {
    id: rootWidget
    
    Layout.preferredWidth: glucoseLabel.implicitWidth + glucoseTrendSpacer.implicitWidth + trendLabel.implicitWidth + mainSpacer.implicitWidth + timeLabel.implicitWidth
    Layout.preferredHeight: Math.max(glucoseLabel.implicitHeight, trendLabel.implicitHeight, timeLabel.implicitHeight)

    Item {
        anchors.fill: parent

        Label {
            id: glucoseLabel
            text: glucose
            color: glucoseColor
            font.pointSize: 24
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
        }

        Item {
            id: glucoseTrendSpacer
            implicitWidth: 2
            anchors.left: glucoseLabel.right
        }

        Label {
            id: trendLabel
            text: trend
            color: glucoseColor
            font.pointSize: 24
            anchors.left: glucoseTrendSpacer.right
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
        }

        Item {
            id: mainSpacer
            implicitWidth: 12
            anchors.left: trendLabel.right
            anchors.right: timeLabel.left
        }

        Label {
            id: timeLabel
            text: timeAgo
            color: "white"
            font.pointSize: 10
            opacity: 0.7
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            font.bold: true
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