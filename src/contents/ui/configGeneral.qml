import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

import "../lib/charsets.js" as Charsets
import "../lib/units.js" as Units

KCMUtils.SimpleKCM {
    id: page

    property string cfg_nightscoutURLDefault: "https://appname.herokuapp.com"
    property string cfg_nightscoutTokenDefault: "plasmoid-0000000"
    property int cfg_charsetDefault: 0
    property int cfg_pollPaddingDefault: 15
    property int cfg_unitsDefault: 1
    property real cfg_chartMinDefault: 0
    property real cfg_chartMaxDefault: 15
    property real cfg_urgentLowDefault: 3.9
    property real cfg_targetLowDefault: 4.5
    property real cfg_targetHighDefault: 10.0
    property real cfg_urgentHighDefault: 13.4
    property int cfg_chartHoursDefault: 3
    property string cfg_rapidNameDefault: "Admelog"
    property string cfg_basalNameDefault: "Tresiba"
    property bool cfg_showBasalDefault: true

    property alias cfg_nightscoutURL: nightscoutURL.text
    property alias cfg_nightscoutToken: nightscoutToken.text
    property alias cfg_charset: charset.currentIndex
    property alias cfg_pollPadding: pollPadding.value
    property alias cfg_units: units.currentIndex
    property alias cfg_chartMin: chartMin.text
    property alias cfg_chartMax: chartMax.text
    property alias cfg_urgentLow: urgentLow.text
    property alias cfg_targetLow: targetLow.text
    property alias cfg_targetHigh: targetHigh.text
    property alias cfg_urgentHigh: urgentHigh.text
    property int cfg_chartHours: 3
    property alias cfg_rapidName: rapidName.text
    property alias cfg_basalName: basalName.text
    property alias cfg_showBasal: showBasal.checked

    property int _activeUnit: -1

    function _convertField(field, fromUnit, toUnit) {
        let val = parseFloat(field.text);
        if (!isNaN(val) && val > 0) {
            field.text = Units.convertBound(val, fromUnit, toUnit).toString();
        }
    }

    Component.onCompleted: {
        page._activeUnit = units.currentIndex;
        // Defensive: if unit is mg/dL but stored values are in mmol/L scale (< 35),
        // auto-convert so the settings UI shows realistic mg/dL numbers.
        if (units.currentIndex === Units.Unit.MG_DL) {
            let maxVal = parseFloat(chartMax.text);
            if (!isNaN(maxVal) && maxVal > 0 && maxVal <= 35) {
                chartMax.text = Units.convertBound(maxVal, Units.Unit.MMOL_L, Units.Unit.MG_DL).toString();
            }
            let uHigh = parseFloat(urgentHigh.text);
            if (!isNaN(uHigh) && uHigh > 0 && uHigh <= 35) {
                page._convertField(urgentLow, Units.Unit.MMOL_L, Units.Unit.MG_DL);
                page._convertField(targetLow, Units.Unit.MMOL_L, Units.Unit.MG_DL);
                page._convertField(targetHigh, Units.Unit.MMOL_L, Units.Unit.MG_DL);
                page._convertField(urgentHigh, Units.Unit.MMOL_L, Units.Unit.MG_DL);
            }
        }
    }

    Kirigami.FormLayout {

        QQC2.TextField {
            id: nightscoutURL
            Kirigami.FormData.label: i18n("Nightscout URL")
            placeholderText: "https://your-nightscout.example.com"
        }
        QQC2.TextField {
            id: nightscoutToken
            Kirigami.FormData.label: i18n("Nightscout API token")
            placeholderText: i18n("Token or API secret")
        }
        QQC2.ComboBox {
            id: charset
            Kirigami.FormData.label: i18n("Charset")
            model: [
                Charsets.getCharsetText(Charsets.Charset.UNICODE_1),
                Charsets.getCharsetText(Charsets.Charset.UNICODE_2),
                Charsets.getCharsetText(Charsets.Charset.EMOJI)
            ]
        }
        QQC2.SpinBox {
            id: pollPadding
            Kirigami.FormData.label: i18n("Poll Padding (seconds)")
            from: 0
            to: 300
        }
        QQC2.ComboBox {
            id: units
            Kirigami.FormData.label: i18n("Units")
            model: [
                Units.getUnitText(Units.Unit.MG_DL),
                Units.getUnitText(Units.Unit.MMOL_L)
            ]
            onActivated: (index) => {
                if (page._activeUnit !== -1 && page._activeUnit !== index) {
                    page._convertField(chartMin, page._activeUnit, index);
                    page._convertField(chartMax, page._activeUnit, index);
                    page._convertField(urgentLow, page._activeUnit, index);
                    page._convertField(targetLow, page._activeUnit, index);
                    page._convertField(targetHigh, page._activeUnit, index);
                    page._convertField(urgentHigh, page._activeUnit, index);
                    page._activeUnit = index;
                }
            }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Targets & Chart")
        }

        QQC2.ComboBox {
            id: chartHoursCombo
            Kirigami.FormData.label: i18n("Chart Timeframe")
            model: [
                i18n("3 hours"),
                i18n("6 hours"),
                i18n("12 hours"),
                i18n("24 hours")
            ]
            readonly property var hoursList: [3, 6, 12, 24]
            currentIndex: {
                let idx = hoursList.indexOf(page.cfg_chartHours);
                return idx >= 0 ? idx : 0;
            }
            onActivated: (index) => {
                page.cfg_chartHours = hoursList[index];
            }
        }
        QQC2.TextField {
            id: chartMin
            Kirigami.FormData.label: i18n("Chart Minimum (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }
        QQC2.TextField {
            id: chartMax
            Kirigami.FormData.label: i18n("Chart Maximum (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }
        QQC2.TextField {
            id: urgentLow
            Kirigami.FormData.label: i18n("Urgent Low (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }
        QQC2.TextField {
            id: targetLow
            Kirigami.FormData.label: i18n("Target Low (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }
        QQC2.TextField {
            id: targetHigh
            Kirigami.FormData.label: i18n("Target High (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }
        QQC2.TextField {
            id: urgentHigh
            Kirigami.FormData.label: i18n("Urgent High (%1)", Units.getUnitText(units.currentIndex))
            validator: DoubleValidator { bottom: 0; notation: DoubleValidator.StandardNotation; locale: "C" }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Treatments")
        }

        QQC2.TextField {
            id: rapidName
            Kirigami.FormData.label: i18n("Rapid-Acting Insulin Name")
            placeholderText: "Admelog / Humalog / Novolog / Fiasp"
        }
        QQC2.CheckBox {
            id: showBasal
            Kirigami.FormData.label: i18n("Basal Insulin")
            text: i18n("Show basal button in treatment bar")
        }
        QQC2.TextField {
            id: basalName
            Kirigami.FormData.label: i18n("Basal Insulin Name")
            placeholderText: "Tresiba / Lantus / Toujeo / Levemir"
            visible: showBasal.checked
        }
    }
}
