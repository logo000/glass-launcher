import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.private.kicker as Kicker

PlasmoidItem {
    id: kicker

    // Kicker's models call back into these.
    signal reset
    property bool isDash: false
    property Item dragSource: null

    readonly property bool useCustomButtonImage: Plasmoid.configuration.useCustomButtonImage
        && Plasmoid.configuration.customButtonImage.length > 0

    Plasmoid.status: launcher.shown ? PlasmaCore.Types.RequiresAttentionStatus : PlasmaCore.Types.PassiveStatus

    Plasmoid.icon: useCustomButtonImage ? Plasmoid.configuration.customButtonImage : Plasmoid.configuration.icon

    // The panel only ever shows the button; the launcher is its own window.
    preferredRepresentation: fullRepresentation
    compactRepresentation: null
    fullRepresentation: PanelButton {}

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: "Anwendungen bearbeiten…"
            icon.name: "kmenuedit"
            visible: Plasmoid.immutability !== PlasmaCore.Types.SystemImmutable
            onTriggered: processRunner.runMenuEditor()
        }
    ]

    Kicker.RootModel {
        id: rootModel

        autoPopulate: false
        appNameFormat: 0
        flat: true
        sorted: true
        showSeparators: false
        appletInterface: kicker

        showAllApps: true
        showAllAppsCategorized: false
        showTopLevelItems: true
        showRecentApps: false
        showRecentDocs: false
        showPowerSession: false

        Component.onCompleted: refresh()
    }

    Kicker.ProcessRunner {
        id: processRunner
    }

    LauncherWindow {
        id: launcher
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            launcher.toggle();
        }
    }
}
