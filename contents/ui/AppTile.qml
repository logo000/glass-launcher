import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: tile

    property var view
    property int pageIndex: 0
    property int row: 0
    property int slot: 0

    readonly property bool valid: row < view.count
    // Pulled on demand instead of bound: a QIcon never compares equal, so a
    // binding would make Kirigami.Icon re-rasterize on every model refresh.
    property string name: ""
    property var appIcon: null
    function refresh() {
        if (!valid) {
            if (name !== "") { name = ""; appIcon = null; }
            return;
        }
        const n = String(view.itemData(row, Qt.DisplayRole) ?? "");
        if (n !== name || appIcon === null) {
            name = n;
            appIcon = view.itemData(row, Qt.DecorationRole);
        }
    }
    onRowChanged: refresh()
    onValidChanged: refresh()
    Component.onCompleted: refresh()
    readonly property bool current: (view.keyNav || view.searching) && view.currentRow === row
    readonly property bool hovered: hover.hovered
    readonly property bool pressed: tap.pressed

    // 0 → hidden, 1 → settled. Drives the staggered entrance.
    property real appear: 1

    width: view.cellW
    height: view.cellH
    visible: valid
    opacity: appear

    Accessible.name: name
    Accessible.role: Accessible.Button

    Rectangle {
        anchors.fill: parent
        anchors.margins: 2
        radius: 20
        color: view.tint(tile.pressed ? 0.16 : (tile.current ? 0.14 : (tile.hovered ? 0.09 : 0)))
        border.width: 1
        border.color: view.tint(tile.current ? 0.34 : (tile.hovered ? 0.18 : 0))
        Behavior on border.color { ColorAnimation { duration: view.ms(140) } }
        Behavior on color { ColorAnimation { duration: view.ms(140) } }
    }

    Item {
        id: body
        anchors.fill: parent
        scale: 0.86 + 0.14 * tile.appear
        transform: Translate { y: (1 - tile.appear) * 10 }

        Item {
            id: iconWrap
            anchors.horizontalCenter: parent.horizontalCenter
            y: 10
            width: view.iconSize
            height: view.iconSize

            Kirigami.Icon {
                anchors.fill: parent
                source: tile.appIcon
                animated: false
                scale: tile.pressed ? 0.9 : (tile.hovered ? 1.07 : 1)
                Behavior on scale { NumberAnimation { duration: view.ms(260); easing.type: Easing.OutBack; easing.overshoot: 1.8 } }
            }
        }

        Text {
            textFormat: Text.PlainText
            // soft shadow keeps labels legible on clear glass
            x: label.x
            y: label.y + 1
            width: label.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            text: label.text
            font: label.font
            color: Qt.rgba(0, 0, 0, 0.45)
        }

        Text {
            textFormat: Text.PlainText
            id: label
            anchors.top: iconWrap.bottom
            anchors.topMargin: 8
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            text: tile.name
            color: view.fg
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
            font.weight: Font.Medium
        }
    }

    // Pointer handlers (not a MouseArea) so the pager's swipe DragHandler
    // can take over as soon as the pointer moves sideways.
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        id: tap
        acceptedButtons: Qt.LeftButton
        gesturePolicy: TapHandler.DragThreshold
        onTapped: {
            launchPulse.restart();
            tile.view.launch(tile.row);
        }
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: (eventPoint) => tile.view.openAppMenu(tile.row, tile, eventPoint.position.x, eventPoint.position.y)
    }

    function playIn(delay) {
        enter.stop();
        pop.stop();
        appear = 0;
        enterPause.duration = delay;
        enter.start();
    }

    Connections {
        target: tile.view
        function onRevChanged() { tile.refresh(); }
        function onPlayIntro() {
            if (tile.pageIndex === tile.view.page) {
                tile.playIn(tile.view.ms(Math.min(tile.slot, 28) * 13));
            } else {
                tile.appear = 1;
            }
        }
    }

    // Results reshuffle while typing: give swapped tiles a soft pop.
    onNameChanged: {
        if (view.searching && valid && !enter.running) pop.restart();
    }

    SequentialAnimation {
        id: enter
        PauseAnimation { id: enterPause }
        NumberAnimation { target: tile; property: "appear"; to: 1; duration: view.ms(380); easing.type: Easing.OutCubic }
    }

    NumberAnimation {
        id: pop
        target: tile; property: "appear"
        from: 0.55; to: 1
        duration: view.ms(220); easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: launchPulse
        NumberAnimation { target: iconWrap; property: "scale"; to: 1.18; duration: view.ms(110); easing.type: Easing.OutQuad }
        NumberAnimation { target: iconWrap; property: "scale"; to: 1; duration: view.ms(200); easing.type: Easing.OutBack }
    }
}
