import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

KCMUtils.SimpleKCM {
    id: page

    property bool cfg_showPollRingDefault: true
    property bool cfg_autoRingSizeDefault: true
    property int cfg_customRingSizeDefault: 24
    property bool cfg_autoFontSizeDefault: true
    property int cfg_customFontSizeDefault: 14
    property bool cfg_boldTextDefault: true
    property bool cfg_matchTrendSizeDefault: true
    property int cfg_customTrendSizeDefault: 14
    property int cfg_itemSpacingDefault: 4
    property int cfg_horizontalMarginDefault: 2

    property alias cfg_showPollRing: showPollRing.checked
    property alias cfg_autoRingSize: autoRingSize.checked
    property alias cfg_customRingSize: customRingSize.value
    property alias cfg_autoFontSize: autoFontSize.checked
    property alias cfg_customFontSize: customFontSize.value
    property alias cfg_boldText: boldText.checked
    property alias cfg_matchTrendSize: matchTrendSize.checked
    property alias cfg_customTrendSize: customTrendSize.value
    property alias cfg_itemSpacing: itemSpacing.value
    property alias cfg_horizontalMargin: horizontalMargin.value

    Kirigami.FormLayout {

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Text & Font")
        }

        QQC2.CheckBox {
            id: boldText
            Kirigami.FormData.label: i18n("Font style:")
            text: i18n("Bold text")
        }

        QQC2.CheckBox {
            id: autoFontSize
            Kirigami.FormData.label: i18n("Glucose font size:")
            text: i18n("Automatic (scale to panel height)")
        }

        QQC2.SpinBox {
            id: customFontSize
            Kirigami.FormData.label: i18n("Custom font size (pt):")
            from: 6
            to: 72
            stepSize: 1
            editable: true
            enabled: !autoFontSize.checked
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Trend Arrow")
        }

        QQC2.CheckBox {
            id: matchTrendSize
            Kirigami.FormData.label: i18n("Arrow size:")
            text: i18n("Match glucose text size")
        }

        QQC2.SpinBox {
            id: customTrendSize
            Kirigami.FormData.label: i18n("Custom arrow size (pt):")
            from: 6
            to: 72
            stepSize: 1
            editable: true
            enabled: !matchTrendSize.checked
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Poll Indicator (Ring)")
        }

        QQC2.CheckBox {
            id: showPollRing
            Kirigami.FormData.label: i18n("Indicator:")
            text: i18n("Show poll countdown ring")
        }

        QQC2.CheckBox {
            id: autoRingSize
            Kirigami.FormData.label: i18n("Ring size:")
            text: i18n("Automatic (scale to panel height)")
            visible: showPollRing.checked
        }

        QQC2.SpinBox {
            id: customRingSize
            Kirigami.FormData.label: i18n("Custom ring size (px):")
            from: 8
            to: 96
            stepSize: 2
            editable: true
            enabled: !autoRingSize.checked
            visible: showPollRing.checked
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Spacing & Margins")
        }

        QQC2.SpinBox {
            id: itemSpacing
            Kirigami.FormData.label: i18n("Spacing between items (px):")
            from: 0
            to: 30
            stepSize: 1
            editable: true
        }

        QQC2.SpinBox {
            id: horizontalMargin
            Kirigami.FormData.label: i18n("Panel horizontal margin (px):")
            from: 0
            to: 30
            stepSize: 1
            editable: true
        }
    }
}
