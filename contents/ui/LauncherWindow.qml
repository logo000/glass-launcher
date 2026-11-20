import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as P5Support

// A Plasma dialog, so KWin's Better Blur gets the dialog's rounded blur
// region and renders the liquid glass behind it (see hideThemeFill).
PlasmaCore.Dialog {
    id: win

    title: "de.andre.glasslauncher"
    flags: Qt.WindowStaysOnTopHint
    location: PlasmaCore.Types.Floating
    visible: false

    property bool shown: false
    property double hiddenAt: 0

    mainItem: LauncherView {
        id: view
        window: win
    }

    function toggle() {
        if (shown) {
            hide();
        } else if (Date.now() - hiddenAt > 300) {
            // A click on the panel button first deactivates (and hides) us;
            // don't reopen on that same click.
            show();
        }
    }

    function show() {
        shown = true;
        fadeOut.stop();
        reposition();
        visible = true;
        raise();
        requestActivate();
        view.opened();
        hideThemeFill();
        shadowTimer.restart();
    }

    function hide() {
        if (!shown) return;
        shown = false;
        hiddenAt = Date.now();
        view.closed();
        fadeOut.restart();
    }

    function reposition() {
        let s = kicker.screenGeometry;
        if (!s || s.width <= 0) {
            const scr = Qt.application.screens[0];
            s = Qt.rect(scr.virtualX, scr.virtualY, scr.width, scr.height);
        }
        x = Math.round(s.x + (s.width - width) / 2);
        y = Math.round(s.y + Math.max(48, (s.height - height) * 0.44));
    }

    // ---- glass ----------------------------------------------------------
    // Plasma publishes the dialog's rounded blur region to KWin, so Better
    // Blur draws the real liquid glass behind it. MacTahoe's dialog frame
    // paints a 65 % dark fill over that glass; hide just that frame item and
    // keep everything else (blur region, KWin shadow).
    property string xid: ""
    readonly property P5Support.DataSource shell: P5Support.DataSource {
        engine: "executable"
        onNewData: (source, data) => {
            const out = String(data.stdout || "").trim();
            if (/^0x[0-9a-fA-F]+$/.test(out)) win.xid = out;
            disconnectSource(source);
        }
    }
    // The theme's dialog shadow draws a dark hairline around the glass edge.
    function dropThemeShadow() {
        const find = xid ? "w=" + xid + "; "
            : "w=$(xwininfo -root -tree | grep -m1 '\"de.andre.glasslauncher\"' | awk '{print $1}'); echo \"$w\"; ";
        shell.connectSource(find + "[ -n \"$w\" ] && xprop -id \"$w\" -remove _KDE_NET_WM_SHADOW # " + Date.now());
    }
    readonly property Timer shadowTimer: Timer {
        interval: 40
        onTriggered: win.dropThemeShadow()
    }

    function hideThemeFill() {
        const kids = win.contentItem ? win.contentItem.children : [];
        for (let i = 0; i < kids.length; ++i) {
            const k = kids[i];
            if (k !== view && k.imagePath !== undefined) k.opacity = 0;
        }
    }

    onActiveChanged: {
        if (!active && shown && !view.menuOpen) deactivateTimer.restart();
    }
    // Menus briefly steal activation; only hide if we are still inactive.
    readonly property Timer deactivateTimer: Timer {
        interval: 60
        onTriggered: if (!win.active && !view.menuOpen) win.hide()
    }

    onWidthChanged: if (visible) { reposition(); shadowTimer.restart(); }
    onHeightChanged: if (visible) { reposition(); shadowTimer.restart(); }

    // Window opacity is left alone: Better Blur scales the glass with it.
    // The content fades instead (LauncherView's intro).
    readonly property SequentialAnimation fadeOut: SequentialAnimation {
        NumberAnimation { target: view; property: "opacity"; to: 0; duration: view.ms(130); easing.type: Easing.InCubic }
        ScriptAction { script: { win.visible = false; view.opacity = 1; } }
    }
}
