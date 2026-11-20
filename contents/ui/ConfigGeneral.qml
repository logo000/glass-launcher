import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_useCustomButtonImage: useCustom.checked
    property alias cfg_customButtonImage: customImage.text
    property alias cfg_columns: columns.value
    property alias cfg_rows: rows.value
    property alias cfg_iconSize: iconSize.value
    property alias cfg_startOnFavorites: startFav.checked
    property alias cfg_animations: animations.checked
    property alias cfg_glassTint: glassTint.value
    property alias cfg_cornerRadius: cornerRadius.value

    Kirigami.FormLayout {
        QQC2.CheckBox {
            id: useCustom
            Kirigami.FormData.label: "Panel-Symbol:"
            text: "Eigenes Bild verwenden"
        }
        QQC2.TextField {
            id: customImage
            enabled: useCustom.checked
            placeholderText: "/pfad/zum/bild.png"
            Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.SpinBox {
            id: columns
            Kirigami.FormData.label: "Spalten:"
            from: 4; to: 10
        }
        QQC2.SpinBox {
            id: rows
            Kirigami.FormData.label: "Zeilen:"
            from: 2; to: 6
        }
        QQC2.SpinBox {
            id: iconSize
            Kirigami.FormData.label: "Symbolgröße:"
            from: 40; to: 96; stepSize: 8
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: startFav
            Kirigami.FormData.label: "Verhalten:"
            text: "Mit „Zuletzt“ öffnen"
        }
        QQC2.CheckBox {
            id: animations
            text: "Animationen"
        }

        Item { Kirigami.FormData.isSection: true }

        QQC2.Slider {
            id: glassTint
            Kirigami.FormData.label: "Glas-Tönung:"
            from: 0; to: 80; stepSize: 1
            Layout.minimumWidth: Kirigami.Units.gridUnit * 12
        }
        QQC2.SpinBox {
            id: cornerRadius
            Kirigami.FormData.label: "Eckenradius:"
            from: 0; to: 48
        }
    }
}
