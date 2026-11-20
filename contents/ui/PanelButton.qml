import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

Item {
    id: button

    readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Layout.minimumWidth: vertical ? -1 : height
    Layout.minimumHeight: vertical ? width : -1
    Layout.preferredWidth: Layout.minimumWidth
    Layout.preferredHeight: Layout.minimumHeight

    Accessible.name: Plasmoid.title
    Accessible.role: Accessible.Button

    Kirigami.Icon {
        id: icon
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height)
        height: width
        source: Plasmoid.icon
        active: mouse.containsMouse || launcher.shown
        smooth: true
        scale: mouse.pressed ? 0.88 : 1
        Behavior on scale {
            NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 2.2 }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        onClicked: launcher.toggle()
    }
}
