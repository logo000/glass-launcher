import QtQuick
import QtQuick.Effects
import QtQuick.Templates as T
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.private.kicker as Kicker
import org.kde.plasma.private.sessions as Sessions
import org.kde.plasma.plasma5support as P5Support
import org.kde.kitemmodels as KItemModels
import org.kde.coreaddons as KCoreAddons
import org.kde.kirigami as Kirigami

FocusScope {
    id: root

    property var window

    // ---- layout ---------------------------------------------------------
    readonly property int cols: Plasmoid.configuration.columns
    readonly property int rows: Plasmoid.configuration.rows
    readonly property int per: cols * rows
    readonly property int iconSize: Plasmoid.configuration.iconSize
    readonly property int cellW: iconSize + 48
    readonly property int cellH: iconSize + 50
    readonly property int gapX: 10
    readonly property int gapY: 8
    readonly property int gridW: cols * cellW + (cols - 1) * gapX
    readonly property int gridH: rows * cellH + (rows - 1) * gapY
    readonly property int hpad: 26
    readonly property int vpad: 22
    readonly property int radius: Plasmoid.configuration.cornerRadius

    width: gridW + hpad * 2
    height: column.implicitHeight + vpad * 2

    // ---- look -----------------------------------------------------------
    // The glass is light-on-dark like the panels, independent of the colour scheme.
    readonly property color fg: "#ffffff"
    function tint(a) { return Qt.rgba(1, 1, 1, a); }
    readonly property real glassTint: Plasmoid.configuration.glassTint / 100

    // ---- motion ---------------------------------------------------------
    readonly property real motion: (Plasmoid.configuration.animations && Kirigami.Units.longDuration > 0) ? 1 : 0
    function ms(d) { return Math.round(d * motion); }

    signal playIntro()

    // ---- custom pages ---------------------------------------------------
    // [{ name: "Arbeit", apps: ["code.desktop", …] }, …] stored as JSON.
    readonly property var pages: {
        try {
            const v = JSON.parse(Plasmoid.configuration.customPages || "[]");
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }
    function savePages(list) {
        Plasmoid.configuration.customPages = JSON.stringify(list);
    }
    function clonePages() {
        return pages.map((p) => ({ name: p.name, apps: p.apps.slice() }));
    }
    function cleanId(id) {
        return String(id).replace(/^applications:/, "");
    }
    function addToPage(i, appId) {
        const list = clonePages();
        const id = cleanId(appId);
        if (!list[i] || list[i].apps.indexOf(id) !== -1) return;
        list[i].apps.push(id);
        savePages(list);
    }
    function removeFromPage(i, appId) {
        const list = clonePages();
        const id = cleanId(appId);
        if (!list[i]) return;
        list[i].apps = list[i].apps.filter((a) => a !== id);
        savePages(list);
    }
    function createPage(firstApp) {
        const list = clonePages();
        let n = list.length + 1;
        while (list.some((p) => p.name === "Seite " + n)) n++;
        list.push({ name: "Seite " + n, apps: firstApp ? [cleanId(firstApp)] : [] });
        savePages(list);
        selectTab({ kind: "page", page: list.length - 1 });
        renaming = list.length - 1;
    }
    function renamePage(i, name) {
        if (renaming !== i) return;
        const list = clonePages();
        name = String(name).trim();
        if (list[i] && name.length && name !== list[i].name) {
            const order = tabOrder.slice();
            const at = order.indexOf("p:" + list[i].name);
            if (at !== -1) order[at] = "p:" + name;
            list[i].name = name;
            savePages(list);
            Plasmoid.configuration.tabOrder = JSON.stringify(order);
        }
        renaming = -1;
        search.forceActiveFocus();
    }
    function deletePage(i) {
        const list = clonePages();
        list.splice(i, 1);
        savePages(list);
        if (sel.kind === "page") selectTab({ kind: "all" });
    }
    property int renaming: -1

    Kicker.RecentUsageModel {
        id: recentModel
        shownItems: Kicker.RecentUsageModel.OnlyApps
        ordering: Kicker.RecentUsageModel.Recent
    }

    Kicker.FavoritesModel {
        id: pageModel
        favorites: root.sel.kind === "page" && root.pages[root.sel.page] ? root.pages[root.sel.page].apps : []
    }

    // ---- selection & data ----------------------------------------------
    property var sel: ({ kind: "all" })
    // What the tab bar shows; moves instantly while the grid cross-fades to `sel`.
    property var uiSel: sel
    property var sysCats: []

    readonly property string needle: search.text.trim().toLowerCase()
    readonly property bool searching: needle.length > 0

    readonly property QtObject allApps: rootModel.count > 0 ? rootModel.modelForRow(0) : null
    readonly property QtObject baseModel: {
        if (searching) return allApps;
        switch (sel.kind) {
        case "recent": return recentModel;
        case "page": return pageModel;
        case "row": return rootModel.modelForRow(sel.row);
        default: return allApps;
        }
    }

    property int rev: 0
    readonly property int count: filter.count
    readonly property int pageCount: Math.max(1, Math.ceil(count / per))
    property int currentRow: 0
    property bool keyNav: false
    property int page: 0

    readonly property bool menuOpen: appMenu.status === PlasmaExtras.Menu.Open
        || pageMenu.status === PlasmaExtras.Menu.Open

    KItemModels.KSortFilterProxyModel {
        id: filter
        sourceModel: root.baseModel
        filterRowCallback: (sourceRow, sourceParent) => {
            const q = root.needle;
            if (!q) return true;
            const m = filter.sourceModel;
            const idx = m.index(sourceRow, 0, sourceParent);
            const name = String(m.data(idx, Qt.DisplayRole) ?? "").toLowerCase();
            if (name.indexOf(q) !== -1) return true;
            const desc = root.descRole >= 0 ? m.data(idx, root.descRole) : undefined;
            return !!desc && String(desc).toLowerCase().indexOf(q) !== -1;
        }
        onRowsInserted: Qt.callLater(root.refreshData)
        onRowsRemoved: Qt.callLater(root.refreshData)
        onModelReset: Qt.callLater(root.refreshData)
        onLayoutChanged: Qt.callLater(root.refreshData)
        onDataChanged: Qt.callLater(root.refreshData)
        onSourceModelChanged: {
            root.descRole = sourceModel ? sourceModel.KItemModels.KRoleNames.role("description") : -1;
            Qt.callLater(root.refreshData);
        }
    }
    property int descRole: -1

    onNeedleChanged: {
        filter.invalidateFilter();
        refreshData();
        currentRow = 0;
        goPage(0, false);
    }

    // While searching, best matches first: name prefix, then word prefix,
    // then anywhere in the name, then description-only hits.
    property var order: []
    function refreshData() {
        if (!searching) {
            if (order.length) order = [];
        } else {
            const q = needle;
            const scored = [];
            for (let r = 0; r < filter.count; ++r) {
                const n = String(filter.data(filter.index(r, 0), Qt.DisplayRole) ?? "").toLowerCase();
                let score = 3;
                if (n.startsWith(q)) score = 0;
                else if (n.split(/[\s\-_.()]+/).some((w) => w.startsWith(q))) score = 1;
                else if (n.indexOf(q) !== -1) score = 2;
                scored.push({ r: r, score: score, n: n });
            }
            scored.sort((a, b) => a.score - b.score || a.n.localeCompare(b.n));
            order = scored.map((x) => x.r);
        }
        if (page > pageCount - 1) goPage(pageCount - 1, false);
        rev++;
    }
    function mapRow(row) {
        return order.length ? order[row] : row;
    }
    function role(name) {
        return filter.KItemModels.KRoleNames.role(name);
    }
    function itemData(row, r) {
        if (row < 0 || row >= filter.count) return undefined;
        return filter.data(filter.index(mapRow(row), 0), r);
    }
    function sourceRow(row) {
        return filter.mapToSource(filter.index(mapRow(row), 0)).row;
    }

    readonly property var shortNames: ({
        "Büroprogramme": "Büro", "Office": "Büro",
        "Dienstprogramme": "Tools", "Utilities": "Tools",
        "Multimedia": "Medien",
        "Systemeinstellungen": "Einstellungen", "Settings": "Einstellungen",
        "Wissenschaft & Mathematik": "Wissenschaft", "Science & Math": "Wissenschaft",
        "Lernprogramme": "Lernen", "Education": "Lernen",
        "Development": "Entwicklung", "Graphics": "Grafik", "Games": "Spiele"
    })
    readonly property var hiddenNames: ["Hilfe", "Help", "Verloren & gefunden", "Lost & Found"]

    function rebuildCategories() {
        const list = [];
        for (let i = 1; i < rootModel.count; ++i) {
            const label = rootModel.labelForRow(i);
            if (!label || hiddenNames.indexOf(label) !== -1) continue;
            const m = rootModel.modelForRow(i);
            if (!m || m.count === 0) continue;
            list.push({ label: shortNames[label] ?? label, raw: label, row: i });
        }
        sysCats = list;
        refreshData();
    }

    Connections {
        target: rootModel
        function onRefreshed() { Qt.callLater(root.rebuildCategories); }
        function onCountChanged() { Qt.callLater(root.rebuildCategories); }
    }
    Component.onCompleted: { rebuildCategories(); syncTabs(); }

    // ---- tabs -----------------------------------------------------------
    // Alle, Zuletzt, own pages and categories in one bar, in the user's
    // order (drag to rearrange). Keys survive reloads: "all", "recent",
    // "p:<page name>", "c:<category>".
    readonly property var tabOrder: {
        try {
            const v = JSON.parse(Plasmoid.configuration.tabOrder || "[]");
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }
    readonly property var tabs: {
        const t = [
            { key: "all", kind: "all", label: "Alle", page: -1, row: -1 },
            { key: "recent", kind: "recent", label: "Zuletzt", page: -1, row: -1 }
        ];
        pages.forEach((p, i) => t.push({ key: "p:" + p.name, kind: "page", label: p.name, page: i, row: -1 }));
        sysCats.forEach((c) => t.push({ key: "c:" + c.raw, kind: "row", label: c.label, page: -1, row: c.row }));
        const pos = (k) => {
            let i = tabOrder.indexOf(k);
            if (i === -1 && k === "recent") i = tabOrder.indexOf("fav"); // took Favoriten's place
            return i === -1 ? 1e6 : i;
        };
        return t.map((x, i) => Object.assign({ def: i }, x))
            .sort((a, b) => (pos(a.key) - pos(b.key)) || (a.def - b.def));
    }
    function sameSel(a, b) {
        return a.kind === b.kind && (a.page ?? -1) === (b.page ?? -1) && (a.row ?? -1) === (b.row ?? -1);
    }
    function keyOfSel(s) {
        const t = tabs.find((x) => sameSel(x, s));
        return t ? t.key : "";
    }
    readonly property string uiKey: keyOfSel(uiSel)

    ListModel { id: tabModel }
    property bool draggingTab: false
    property string draggingKey: ""
    property Item draggedPill: null

    function syncTabs() {
        if (draggingTab) return;
        let same = tabModel.count === tabs.length;
        for (let i = 0; same && i < tabs.length; ++i) same = tabModel.get(i).key === tabs[i].key;
        if (same) {
            for (let i = 0; i < tabs.length; ++i) {
                tabModel.setProperty(i, "label", tabs[i].label);
                tabModel.setProperty(i, "page", tabs[i].page);
                tabModel.setProperty(i, "row", tabs[i].row);
            }
        } else {
            tabModel.clear();
            for (const t of tabs) tabModel.append({ key: t.key, kind: t.kind, label: t.label, page: t.page, row: t.row });
        }
        updateCurrentTab();
    }
    onTabsChanged: Qt.callLater(syncTabs)

    function saveTabOrder() {
        const keys = [];
        for (let i = 0; i < tabModel.count; ++i) keys.push(tabModel.get(i).key);
        Plasmoid.configuration.tabOrder = JSON.stringify(keys);
    }
    function updateCurrentTab() {
        for (let i = 0; i < tabModel.count; ++i) {
            if (tabModel.get(i).key === uiKey) {
                tabList.currentIndex = i;
                Qt.callLater(ensureTabVisible, i);
                return;
            }
        }
        tabList.currentIndex = -1;
    }
    onUiKeyChanged: updateCurrentTab()

    function scrollTabs(d) {
        const max = Math.max(0, tabList.contentWidth - tabList.width);
        tabScroll.stop();
        tabList.contentX = Math.max(tabList.originX, Math.min(tabList.originX + max, tabList.contentX + d));
    }
    function ensureTabVisible(i) {
        const item = tabList.itemAtIndex(i);
        if (!item) return;
        const max = Math.max(0, tabList.contentWidth - tabList.width);
        let x = tabList.contentX;
        if (item.x < x + 24) x = item.x - 24;
        else if (item.x + item.width > x + tabList.width - 24) x = item.x + item.width - tabList.width + 24;
        x = Math.max(tabList.originX, Math.min(tabList.originX + max, x));
        if (Math.abs(x - tabList.contentX) < 1) return;
        tabScroll.to = x;
        tabScroll.restart();
    }
    NumberAnimation {
        id: tabScroll
        target: tabList; property: "contentX"
        duration: root.ms(320); easing.type: Easing.OutCubic
    }

    // ---- actions --------------------------------------------------------
    function opened() {
        search.text = "";
        keyNav = false;
        currentRow = 0;
        renaming = -1;
        sel = Plasmoid.configuration.startOnFavorites ? { kind: "recent" } : { kind: "all" };
        uiSel = sel;
        goPage(0, false);
        intro.restart();
        playIntro();
        search.forceActiveFocus();
    }
    function closed() {
        appMenu.close();
        pageMenu.close();
    }

    function selectTab(s) {
        uiSel = s;
        if (sameSel(s, sel)) return;
        tabSwitch.next = s;
        tabSwitch.restart();
    }

    function launch(row) {
        if (row < 0 || row >= count) return;
        const closes = baseModel.trigger(sourceRow(row), "", null);
        if (closes !== false) closeTimer.restart();
    }

    function goPage(p, animate) {
        p = Math.max(0, Math.min(pageCount - 1, p));
        page = p;
        pageAnim.stop();
        if (animate === false || motion === 0) {
            pager.contentX = p * pager.width;
        } else {
            pageAnim.to = p * pager.width;
            pageAnim.start();
        }
        if (keyNav && Math.floor(currentRow / per) !== p) currentRow = p * per;
    }

    function moveSelection(delta) {
        if (count === 0) return;
        keyNav = true;
        currentRow = Math.max(0, Math.min(count - 1, currentRow + delta));
        const p = Math.floor(currentRow / per);
        if (p !== page) goPage(p);
    }

    // ---- menus ----------------------------------------------------------
    function fillMenu(menu, items) {
        menu.clearMenuItems();
        for (const a of items) {
            const mi = menuItemComponent.createObject(menu, {
                text: a.text ?? "",
                separator: a.type === "separator",
                section: a.type === "title",
                enabled: a.type !== "title" && (a.enabled ?? true),
                checkable: !!a.checkable,
                checked: !!a.checked
            });
            if (a.icon) mi.icon = a.icon;
            if (a.run) mi.clicked.connect(a.run);
            menu.addMenuItem(mi);
        }
    }

    function openAppMenu(row, tile, x, y) {
        const favId = itemData(row, role("favoriteId"));
        const items = [];
        if (itemData(row, role("hasActionList"))) {
            const actions = itemData(row, role("actionList")) || [];
            const src = sourceRow(row);
            const model = baseModel;
            for (const a of actions) {
                items.push({
                    text: a.text, icon: a.icon, type: a.type,
                    run: () => { if (model.trigger(src, a.actionId, a.actionArgument)) root.window.hide(); }
                });
            }
            if (items.length) items.push({ type: "separator" });
        }
        if (favId) {
            const id = cleanId(favId);
            pages.forEach((p, i) => {
                const has = p.apps.indexOf(id) !== -1;
                items.push(has
                    ? { text: "Aus „" + p.name + "“ entfernen", icon: "list-remove", run: () => root.removeFromPage(i, id) }
                    : { text: "Zu „" + p.name + "“ hinzufügen", icon: "list-add", run: () => root.addToPage(i, id) });
            });
            items.push({ text: "Neue Seite mit dieser App", icon: "list-add", run: () => root.createPage(id) });
        }
        items.push({ type: "separator" });
        items.push({ text: "Anwendungen bearbeiten…", icon: "kmenuedit", run: () => { processRunner.runMenuEditor(); root.window.hide(); } });
        fillMenu(appMenu, items);
        appMenu.visualParent = tile;
        appMenu.open(x, y);
    }

    function openPageMenu(i, pill) {
        fillMenu(pageMenu, [
            { text: "Umbenennen", icon: "edit-rename", run: () => { root.selectTab({ kind: "page", page: i }); root.renaming = i; } },
            { type: "separator" },
            { text: "Seite löschen", icon: "edit-delete", run: () => root.deletePage(i) }
        ]);
        pageMenu.visualParent = pill;
        pageMenu.open(0, pill.height + 4);
    }

    PlasmaExtras.Menu { id: appMenu }
    PlasmaExtras.Menu { id: pageMenu }
    Component {
        id: menuItemComponent
        PlasmaExtras.MenuItem {}
    }

    Timer {
        id: closeTimer
        interval: root.ms(150)
        onTriggered: root.window.hide()
    }

    Sessions.SessionManagement { id: session }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source) => disconnectSource(source)
    }

    KCoreAddons.KUser { id: user }

    // ---- animations -----------------------------------------------------
    ParallelAnimation {
        id: intro
        NumberAnimation { target: column; property: "opacity"; from: 0; to: 1; duration: root.ms(240); easing.type: Easing.OutCubic }
        NumberAnimation { target: column; property: "scale"; from: 0.97; to: 1; duration: root.ms(360); easing.type: Easing.OutQuint }
    }

    SequentialAnimation {
        id: tabSwitch
        property var next: ({ kind: "all" })
        NumberAnimation { target: pagerWrap; property: "opacity"; to: 0; duration: root.ms(90); easing.type: Easing.InQuad }
        ScriptAction {
            script: {
                root.sel = tabSwitch.next;
                root.currentRow = 0;
                root.goPage(0, false);
            }
        }
        // Let the swapped tiles render once while still hidden, then reveal.
        PauseAnimation { duration: root.ms(32) }
        ScriptAction {
            script: {
                pagerWrap.opacity = 1;
                root.playIntro();
            }
        }
    }

    NumberAnimation {
        id: pageAnim
        target: pager; property: "contentX"
        duration: root.ms(440); easing.type: Easing.OutCubic
    }

    // ---- keyboard -------------------------------------------------------
    function handleKey(event) {
        switch (event.key) {
        case Qt.Key_Escape:
            if (search.text.length) search.text = "";
            else window.hide();
            break;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            launch(currentRow);
            break;
        case Qt.Key_Down:
            moveSelection(cols);
            break;
        case Qt.Key_Up:
            moveSelection(-cols);
            break;
        case Qt.Key_Left:
            if (searching && !keyNav) return;
            moveSelection(-1);
            break;
        case Qt.Key_Right:
            if (searching && !keyNav) return;
            moveSelection(1);
            break;
        case Qt.Key_PageDown:
            goPage(page + 1);
            break;
        case Qt.Key_PageUp:
            goPage(page - 1);
            break;
        case Qt.Key_Tab:
        case Qt.Key_Backtab: {
            if (searching) break;
            const i = tabs.findIndex((t) => sameSel(t, sel));
            const d = event.key === Qt.Key_Tab ? 1 : -1;
            selectTab(tabs[(Math.max(0, i) + d + tabs.length) % tabs.length]);
            break;
        }
        default:
            return;
        }
        event.accepted = true;
    }

    // ---- glass ----------------------------------------------------------
    // KWin draws the blur and the edge refraction behind the window (see
    // LauncherWindow). Optional tint from the settings, off by default.

    // The tint reaches under the (hidden) dialog frame up to the glass edge.
    readonly property var frameMargins: window ? window.margins : null
    Item {
        id: glassArea
        anchors.fill: parent
        anchors.leftMargin: root.frameMargins ? -root.frameMargins.left : 0
        anchors.topMargin: root.frameMargins ? -root.frameMargins.top : 0
        anchors.rightMargin: root.frameMargins ? -root.frameMargins.right : 0
        anchors.bottomMargin: root.frameMargins ? -root.frameMargins.bottom : 0
    }

    Rectangle {
        anchors.fill: glassArea
        radius: root.radius
        visible: root.glassTint > 0
        color: Qt.rgba(0.06, 0.07, 0.10, root.glassTint)
    }

    // ---- content --------------------------------------------------------
    Column {
        id: column
        y: root.vpad
        width: root.width
        spacing: 16
        transformOrigin: Item.Top

        // Search
        Rectangle {
            id: searchBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.gridW
            height: 40
            radius: height / 2
            color: root.tint(search.activeFocus ? 0.13 : 0.09)
            border.width: 1
            border.color: root.tint(search.activeFocus ? 0.30 : 0.16)
            Behavior on color { ColorAnimation { duration: root.ms(160) } }
            Behavior on border.color { ColorAnimation { duration: root.ms(160) } }

            Kirigami.Icon {
                id: searchIcon
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 16; height: 16
                source: "search"
                color: root.fg
                isMask: true
                opacity: 0.75
            }

            TextInput {
                id: search
                anchors.left: searchIcon.right
                anchors.leftMargin: 10
                anchors.right: clearButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                color: root.fg
                selectionColor: Kirigami.Theme.highlightColor
                selectedTextColor: Kirigami.Theme.highlightedTextColor
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.08
                clip: true
                focus: true
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: (event) => root.handleKey(event)

                Text {
                    anchors.fill: parent
                    verticalAlignment: Text.AlignVCenter
                    text: "Apps suchen"
                    color: root.fg
                    opacity: search.text.length ? 0 : 0.6
                    font: search.font
                    Behavior on opacity { NumberAnimation { duration: root.ms(120) } }
                }
            }

            T.AbstractButton {
                id: clearButton
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 24; height: 24
                opacity: search.text.length ? 1 : 0
                visible: opacity > 0
                scale: search.text.length ? 1 : 0.6
                Behavior on opacity { NumberAnimation { duration: root.ms(140) } }
                Behavior on scale { NumberAnimation { duration: root.ms(200); easing.type: Easing.OutBack } }
                Accessible.name: "Suche leeren"
                background: Rectangle { radius: 12; color: root.tint(clearButton.hovered ? 0.22 : 0.12) }
                contentItem: Kirigami.Icon { source: "edit-clear-symbolic"; color: root.fg; isMask: true; implicitWidth: 14; implicitHeight: 14 }
                onClicked: { search.text = ""; search.forceActiveFocus(); }
            }
        }

        // Tabs  ⟷  result count while searching
        Item {
            width: parent.width
            height: 36

            Row {
                anchors.centerIn: parent
                spacing: 8
                opacity: root.searching ? 0 : 1
                visible: opacity > 0
                scale: root.searching ? 0.96 : 1
                Behavior on opacity { NumberAnimation { duration: root.ms(180); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: root.ms(220); easing.type: Easing.OutCubic } }

                Item {
                    id: tabBar
                    readonly property real maxW: root.gridW - 44
                    readonly property bool overflow: tabList.contentWidth + 8 > maxW
                    width: Math.min(maxW, tabList.contentWidth + 8)
                    height: 36

                    Rectangle {
                        anchors.fill: parent
                        radius: height / 2
                        color: Qt.rgba(0, 0, 0, 0.16)
                        border.width: 1
                        border.color: root.tint(0.10)
                    }

                    ListView {
                        id: tabList
                        anchors.fill: parent
                        anchors.margins: 4
                        orientation: ListView.Horizontal
                        spacing: 2
                        clip: true
                        interactive: false
                        boundsBehavior: Flickable.StopAtBounds
                        model: tabModel

                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: root.ms(260)
                        highlightMoveVelocity: -1
                        highlightResizeDuration: root.ms(260)
                        highlightResizeVelocity: -1
                        highlight: Rectangle {
                            radius: height / 2
                            color: root.tint(0.22)
                            border.width: 1
                            border.color: root.tint(0.40)
                            visible: !(root.draggingTab && root.draggingKey === root.uiKey)
                        }

                        displaced: Transition { NumberAnimation { properties: "x"; duration: root.ms(220); easing.type: Easing.OutCubic } }
                        moveDisplaced: Transition { NumberAnimation { properties: "x"; duration: root.ms(220); easing.type: Easing.OutCubic } }

                        layer.enabled: tabBar.overflow
                        layer.effect: MultiEffect {
                            maskEnabled: true
                            maskSource: tabFade
                            maskThresholdMin: 0.0
                            maskSpreadAtMin: 1.0
                        }

                        delegate: Item {
                            id: slot
                            required property int index
                            required property string key
                            required property string kind
                            required property string label
                            required property int page
                            required property int row
                            readonly property bool active: key === root.uiKey
                            readonly property bool editing: kind === "page" && root.renaming === page

                            width: body.width
                            height: tabList.height

                            DropArea {
                                anchors.fill: parent
                                keys: ["glass-tab"]
                                onEntered: (drag) => {
                                    const from = drag.source.slotIndex;
                                    if (from !== undefined && from !== slot.index) tabModel.move(from, slot.index, 1);
                                }
                            }

                            z: reordering ? 10 : 0

                            // Drag a pill to reorder; the bar itself scrolls with swipe / wheel.
                            readonly property bool armed: dragger.active
                            readonly property bool reordering: dragger.active

                            Item {
                                id: body
                                property int slotIndex: slot.index
                                width: slot.editing ? Math.max(90, editor.contentWidth + 28) : pillText.implicitWidth + 28
                                height: slot.height
                                // Follows the pointer; compensates when the slot itself moves during reordering.
                                x: slot.reordering ? dragger.activeTranslation.x - (slot.x - dragger.startSlotX) : 0
                                Behavior on x { enabled: !slot.reordering; NumberAnimation { duration: root.ms(220); easing.type: Easing.OutCubic } }
                                Drag.active: slot.reordering
                                Drag.source: body
                                Drag.keys: ["glass-tab"]
                                Drag.hotSpot.x: width / 2
                                Drag.hotSpot.y: height / 2
                                scale: slot.armed ? 1.07 : 1
                                Behavior on scale { NumberAnimation { duration: root.ms(160); easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: root.tint(slot.armed ? 0.26 : (hover.hovered && !slot.active ? 0.10 : 0))
                                    border.width: 1
                                    border.color: root.tint(slot.armed ? 0.45 : 0)
                                    Behavior on color { ColorAnimation { duration: root.ms(120) } }
                                }

                                Text {
                                    id: pillText
                                    anchors.centerIn: parent
                                    visible: !slot.editing
                                    text: slot.label
                                    color: root.tint(slot.active || slot.armed ? 1 : 0.78)
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                    font.weight: Font.Medium
                                    Behavior on color { ColorAnimation { duration: root.ms(200) } }
                                }

                                TextInput {
                                    id: editor
                                    visible: slot.editing
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 14
                                    width: Math.max(60, contentWidth)
                                    color: "white"
                                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                                    font.weight: Font.Medium
                                    selectByMouse: true
                                    onVisibleChanged: if (visible) { text = slot.label; selectAll(); forceActiveFocus(); }
                                    Keys.onReturnPressed: root.renamePage(slot.page, text)
                                    Keys.onEnterPressed: root.renamePage(slot.page, text)
                                    Keys.onEscapePressed: root.renamePage(slot.page, slot.label)
                                    onActiveFocusChanged: if (!activeFocus && slot.editing) root.renamePage(slot.page, text)
                                }
                            }

                            HoverHandler {
                                id: hover
                                cursorShape: slot.reordering ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                            }
                            TapHandler {
                                enabled: !slot.editing
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                gesturePolicy: TapHandler.DragThreshold
                                onTapped: (eventPoint, button) => {
                                    if (button === Qt.RightButton) {
                                        if (slot.kind === "page") root.openPageMenu(slot.page, body);
                                    } else {
                                        root.selectTab({ kind: slot.kind, page: slot.page, row: slot.row });
                                    }
                                }
                            }
                            DragHandler {
                                id: dragger
                                enabled: !slot.editing
                                target: null
                                xAxis.enabled: true
                                yAxis.enabled: false
                                property real startSlotX: 0
                                onActiveChanged: {
                                    if (active) {
                                        startSlotX = slot.x;
                                        tabScroll.stop();
                                    } else {
                                        body.Drag.drop();
                                    }
                                    root.draggingTab = active;
                                    root.draggingKey = active ? slot.key : "";
                                    root.draggedPill = active ? body : null;
                                    if (!active) {
                                        root.saveTabOrder();
                                        root.updateCurrentTab();
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: tabFade
                        anchors.fill: tabList
                        visible: false
                        layer.enabled: true
                        Rectangle {
                            anchors.fill: parent
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.05; color: "black" }
                                GradientStop { position: 0.95; color: "black" }
                                GradientStop { position: 1.0; color: "transparent" }
                            }
                        }
                    }

                    // Scroll the bar with the touchpad (both directions) or the wheel.
                    WheelHandler {
                        target: null
                        orientation: Qt.Horizontal
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => { root.scrollTabs(-(event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x / 3)); }
                    }
                    WheelHandler {
                        target: null
                        orientation: Qt.Vertical
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: (event) => { root.scrollTabs(-(event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 3)); }
                    }

                    // While dragging a pill near an edge, scroll the bar along.
                    Timer {
                        interval: 16
                        repeat: true
                        running: root.draggingTab && tabBar.overflow
                        onTriggered: {
                            const p = root.draggedPill;
                            if (!p) return;
                            const x = p.mapToItem(tabBar, 0, 0).x;
                            if (x < 20) root.scrollTabs(-8);
                            else if (x + p.width > tabBar.width - 20) root.scrollTabs(8);
                        }
                    }
                }

                RoundIconButton {
                    icon.name: "list-add"
                    text: "Neue Seite"
                    onClicked: root.createPage("")
                }
            }

            Text {
                anchors.centerIn: parent
                text: root.count === 1 ? "1 App gefunden" : root.count + " Apps gefunden"
                color: root.fg
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 0.95
                font.weight: Font.Medium
                opacity: root.searching && root.count > 0 ? 0.85 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: root.ms(180) } }
            }
        }

        // Pages — full window width so sliding pages glide out at the glass edge
        Item {
            id: pagerWrap
            width: parent.width
            height: root.gridH + 8

            ListView {
                id: pager
                anchors.fill: parent
                orientation: ListView.Horizontal
                interactive: false
                cacheBuffer: width
                reuseItems: true
                clip: true
                // A fixed page count keeps the page delegates (and their tiles)
                // alive across tab switches; only the tile contents change.
                // goPage() never goes past root.pageCount.
                model: 40

                delegate: Item {
                    id: pageItem
                    required property int index
                    width: pager.width
                    height: pager.height

                    Grid {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        columns: root.cols
                        columnSpacing: root.gapX
                        rowSpacing: root.gapY

                        Repeater {
                            model: root.per
                            delegate: AppTile {
                                view: root
                                pageIndex: pageItem.index
                                row: pageItem.index * root.per + index
                                slot: index
                            }
                        }
                    }
                }
            }

            // Mouse / touchscreen drag to swipe between pages.
            DragHandler {
                id: swipe
                target: null
                xAxis.enabled: true
                yAxis.enabled: false
                property real startX: 0
                onActiveChanged: {
                    if (active) {
                        pageAnim.stop();
                        startX = pager.contentX;
                    } else {
                        const dx = pager.contentX - startX;
                        let p = root.page;
                        if (dx > pager.width * 0.12) p++;
                        else if (dx < -pager.width * 0.12) p--;
                        root.goPage(p);
                    }
                }
                onActiveTranslationChanged: {
                    if (!active) return;
                    const max = (root.pageCount - 1) * pager.width;
                    let x = startX - activeTranslation.x;
                    if (x < 0) x *= 0.3;
                    else if (x > max) x = max + (x - max) * 0.3;
                    pager.contentX = x;
                }
            }

            // Two-finger swipe (sideways or up/down) and the mouse wheel page.
            // One gesture = one page.
            QtObject {
                id: wheel
                property real acc: 0
                property bool locked: false
                function feed(event, delta) {
                    gestureEnd.restart();
                    if (locked) return;
                    acc += delta;
                    if (Math.abs(acc) >= 60) {
                        root.goPage(root.page + (acc > 0 ? 1 : -1));
                        acc = 0;
                        locked = true;
                        maxLock.restart();
                    }
                }
            }
            WheelHandler {
                target: null
                orientation: Qt.Horizontal
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => wheel.feed(event, -(event.pixelDelta.x !== 0 ? event.pixelDelta.x * 2 : event.angleDelta.x))
            }
            WheelHandler {
                target: null
                orientation: Qt.Vertical
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: (event) => wheel.feed(event, -(event.pixelDelta.y !== 0 ? event.pixelDelta.y * 2 : event.angleDelta.y))
            }
            // A swipe keeps emitting events (incl. momentum): unlock once they
            // pause, or after a while for a continuously spinning wheel.
            Timer { id: gestureEnd; interval: 180; onTriggered: { wheel.locked = false; wheel.acc = 0; } }
            Timer { id: maxLock; interval: 650; onTriggered: { wheel.locked = false; wheel.acc = 0; } }

            Text {
                anchors.centerIn: parent
                width: root.gridW - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.searching ? "Keine App für „" + search.text.trim() + "“"
                    : root.sel.kind === "page" ? "Diese Seite ist noch leer.\nRechtsklick auf eine App → Seite anhaken."
                    : root.sel.kind === "recent" ? "Noch keine zuletzt benutzten Apps."
                    : "Hier ist noch nichts"
                color: root.fg
                font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.05
                lineHeight: 1.3
                opacity: root.count === 0 ? 0.8 : 0
                visible: opacity > 0
                Behavior on opacity { NumberAnimation { duration: root.ms(160) } }
            }
        }

        // Page dots
        Item {
            width: parent.width
            height: 10

            Row {
                anchors.centerIn: parent
                spacing: 8
                opacity: root.pageCount > 1 ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: root.ms(160) } }

                Repeater {
                    model: root.pageCount
                    delegate: T.AbstractButton {
                        id: dot
                        required property int index
                        readonly property bool active: root.page === index
                        width: active ? 22 : 8
                        height: 8
                        Accessible.name: "Seite " + (index + 1)
                        Behavior on width { NumberAnimation { duration: root.ms(320); easing.type: Easing.OutCubic } }
                        background: Rectangle {
                            radius: 4
                            color: root.tint(dot.active ? 0.95 : (dot.hovered ? 0.6 : 0.35))
                            Behavior on color { ColorAnimation { duration: root.ms(200) } }
                        }
                        onClicked: root.goPage(index)
                    }
                }
            }
        }

        // Footer
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: root.gridW
            height: 49

            Rectangle {
                width: parent.width
                height: 1
                color: root.tint(0.12)
            }

            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                height: 36
                spacing: 10

                Item {
                    width: 32; height: 32
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        visible: face.status !== Image.Ready
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#f4b860" }
                            GradientStop { position: 1; color: "#d9534f" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: (user.fullName || user.loginName || "?").charAt(0).toUpperCase()
                            color: "white"
                            font.weight: Font.DemiBold
                        }
                    }
                    Kirigami.ShadowedImage {
                        id: face
                        anchors.fill: parent
                        radius: width / 2
                        source: user.faceIconUrl
                        sourceSize: Qt.size(64, 64)
                        fillMode: Image.PreserveAspectCrop
                        visible: status === Image.Ready
                    }
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: user.fullName || user.loginName
                    color: root.fg
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize
                    font.weight: Font.Medium
                }
            }

            Row {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 36
                spacing: 8

                RoundIconButton {
                    icon.name: "configure"
                    text: "Systemeinstellungen"
                    onClicked: { exec.connectSource("systemsettings"); root.window.hide(); }
                }
                RoundIconButton {
                    icon.name: "system-lock-screen"
                    text: "Sperren"
                    enabled: session.canLock
                    onClicked: { root.window.hide(); session.lock(); }
                }
                RoundIconButton {
                    icon.name: "system-shutdown"
                    text: "Ausschalten …"
                    onClicked: { root.window.hide(); session.requestLogoutPrompt(); }
                }
            }
        }
    }

    component RoundIconButton: T.AbstractButton {
        id: btn
        width: 36
        height: 36
        anchors.verticalCenter: parent.verticalCenter
        display: T.AbstractButton.IconOnly
        Accessible.name: text
        QQC2.ToolTip.text: text
        QQC2.ToolTip.visible: hovered
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
        scale: pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: root.ms(160); easing.type: Easing.OutBack } }
        background: Rectangle {
            radius: width / 2
            color: root.tint(btn.hovered ? 0.2 : 0.09)
            Behavior on color { ColorAnimation { duration: root.ms(140) } }
        }
        contentItem: Item {
            Kirigami.Icon {
                anchors.centerIn: parent
                width: 18; height: 18
                source: btn.icon.name
                color: root.fg
                isMask: true
            }
        }
    }
}
