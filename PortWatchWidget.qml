pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.DCommon.Widgets
import qs.Modules.Plugins
import "PortWatchModel.js" as Model

PluginComponent {
    id: root

    property var popoutService: null

    readonly property string githubDataUrl: "https://raw.githubusercontent.com/4lwayz/portwatch-vi/main/data/tracker.json"
    readonly property string githubRepoUrl: "https://github.com/4lwayz/portwatch-vi"

    readonly property string barDisplayMode: pluginData.barDisplayMode || "nameAndPct"
    readonly property bool showBarFps: pluginData.showBarFps === true
    readonly property bool includePrivateInTop: pluginData.includePrivateInTop === true
    readonly property int refreshIntervalMinutes: {
        const mins = parseInt(pluginData.refreshIntervalMinutes, 10);
        return (Number.isFinite(mins) && mins >= 1) ? Math.min(1440, mins) : 15;
    }

    readonly property string instanceId: Math.random().toString(36).substring(2)
    property int _fetchSerial: 0
    property int _relativeTick: 0

    PluginGlobalVar {
        id: globalRawData
        varName: "rawData"
        defaultValue: null
    }

    PluginGlobalVar {
        id: globalIsFetching
        varName: "isFetching"
        defaultValue: false
    }

    PluginGlobalVar {
        id: globalLastError
        varName: "lastError"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalLastFetchedAt
        varName: "lastFetchedAt"
        defaultValue: 0
    }

    PluginGlobalVar {
        id: globalOwnerId
        varName: "ownerId"
        defaultValue: ""
    }

    PluginGlobalVar {
        id: globalActiveFilter
        varName: "activeFilter"
        defaultValue: "race"
    }

    readonly property bool isFetching: globalIsFetching.value === true
    readonly property string lastError: globalLastError.value || ""

    readonly property var model: {
        void root._relativeTick;
        return Model.buildModel(globalRawData.value, root.includePrivateInTop, Date.now());
    }

    readonly property var barLeader: model.valid ? model.barLeader : null
    readonly property bool hasData: model.valid && barLeader !== null
    readonly property color pillIconAccent: {
        if (!hasData && lastError.length > 0)
            return Theme.error;
        if (hasData && barLeader.playable)
            return Theme.primary;
        return Theme.widgetIconColor;
    }

    readonly property string horizontalRepoLabel: {
        if (!hasData)
            return lastError.length > 0 ? "PortWatch !" : "PortWatch";
        if (barDisplayMode === "pctOnly")
            return "";
        if (barDisplayMode === "compact")
            return "VI";
        return barLeader.name;
    }

    readonly property string horizontalPctLabel: {
        if (!hasData)
            return isFetching ? "…" : "";
        let text = barLeader.scoreText;
        if (showBarFps && barLeader.hasFps)
            text += " • " + barLeader.fpsShort;
        return text;
    }

    readonly property string verticalPillText: {
        if (!hasData)
            return isFetching ? "…" : "VI";
        return Math.round(barLeader.score) + "%";
    }

    function openExternalUrl(url) {
        if (!url || !/^https?:\/\//.test(url))
            return;
        if (!Qt.openUrlExternally(url))
            Quickshell.execDetached(["xdg-open", url]);
    }

    function findEffortById(effortId) {
        if (!effortId || !model.items)
            return null;
        for (let i = 0; i < model.items.length; i++) {
            if (model.items[i].id === effortId)
                return model.items[i];
        }
        return null;
    }

    function fetchTrackerData(force) {
        if (!force && isFetching)
            return;
        if (!force && globalLastFetchedAt.value > 0 && (Date.now() - globalLastFetchedAt.value) < 60000)
            return;

        const url = githubDataUrl + "?ts=" + Math.floor(Date.now() / 60000);
        const serial = ++_fetchSerial;
        globalIsFetching.set(true);
        if (force)
            globalLastError.set("");

        Proc.runCommand(
            "portwatchVi.fetch",
            [Proc.dmsBin, "dl", "--connect-timeout", "8", "--timeout", "15", url],
            (stdout, exitCode) => {
                if (serial !== _fetchSerial)
                    return;

                globalIsFetching.set(false);
                if (exitCode === 0 && stdout && stdout.trim().length > 0) {
                    try {
                        const parsed = JSON.parse(stdout);
                        if (parsed && Array.isArray(parsed.efforts)) {
                            globalRawData.set(parsed);
                            globalLastError.set("");
                            globalLastFetchedAt.set(Date.now());
                            if (pluginService)
                                pluginService.savePluginState("portwatchVi", "cachedTracker", parsed);
                            return;
                        }
                    } catch (e) {
                        globalLastError.set("Invalid tracker JSON from GitHub.");
                        return;
                    }
                }

                globalLastError.set("Could not reach github.com/4lwayz/portwatch-vi.");
            },
            50,
            20000,
            root
        );
    }

    function maybeBackgroundRefresh() {
        const staleMs = 3 * 60 * 1000;
        if (globalLastFetchedAt.value === 0 || (Date.now() - globalLastFetchedAt.value) >= staleMs)
            fetchTrackerData(false);
    }

    function ensureOwner() {
        if (root.surfaceLive && !globalOwnerId.value)
            globalOwnerId.set(root.instanceId);
    }

    function _bootstrapState() {
        if (pluginService && globalRawData.value === null) {
            const cached = pluginService.loadPluginState("portwatchVi", "cachedTracker", null);
            if (cached && Array.isArray(cached.efforts))
                globalRawData.set(cached);
        }
        ensureOwner();
    }

    onPluginServiceChanged: _bootstrapState()

    onSurfaceLiveChanged: {
        if (root.surfaceLive)
            ensureOwner();
        else if (globalOwnerId.value === root.instanceId)
            globalOwnerId.set("");
    }

    Component.onCompleted: {
        _bootstrapState();
        initFetchTimer.start();
    }

    Component.onDestruction: {
        ownerClaimTimer.stop();
        Proc.release("portwatchVi.fetch");
        if (globalOwnerId.value === root.instanceId)
            globalOwnerId.set("");
    }

    Connections {
        target: globalOwnerId
        function onValueChanged() {
            if (root.surfaceLive && !globalOwnerId.value)
                ownerClaimTimer.restart();
        }
    }

    Timer {
        id: ownerClaimTimer
        interval: 0
        repeat: false
        onTriggered: root.ensureOwner()
    }

    Timer {
        id: initFetchTimer
        interval: 250
        repeat: false
        onTriggered: {
            root.ensureOwner();
            if (globalOwnerId.value === root.instanceId)
                root.fetchTrackerData(false);
        }
    }

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMinutes * 60 * 1000
        repeat: true
        running: root.surfaceLive && globalOwnerId.value === root.instanceId
        onTriggered: root.fetchTrackerData(false)
    }

    pillRightClickAction: () => {
        root.fetchTrackerData(true);
        if (typeof ToastService !== "undefined")
            ToastService.showInfo("PortWatch VI: refreshing leaderboard…");
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DIcon {
                name: "sports_esports"
                size: root.iconSize
                color: root.pillIconAccent
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                visible: root.horizontalRepoLabel.length > 0
                text: root.horizontalRepoLabel
                width: Math.min(implicitWidth, Theme.fontSizeMedium * 10)
                elide: Text.ElideRight
                font.pixelSize: root.textSize
                font.weight: Font.Medium
                color: Theme.widgetTextColor
                wrapMode: Text.NoWrap
                anchors.verticalCenter: parent.verticalCenter
            }

            NumericText {
                visible: root.horizontalPctLabel.length > 0
                text: root.horizontalPctLabel
                font.pixelSize: root.textSize
                font.weight: Font.Bold
                color: (root.hasData && root.barLeader && root.barLeader.playable) ? Theme.primary : Theme.widgetTextColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXXS

            DIcon {
                name: "sports_esports"
                size: root.iconSize
                color: root.pillIconAccent
                anchors.horizontalCenter: parent.horizontalCenter
            }

            NumericText {
                text: root.verticalPillText
                font.pixelSize: root.textSize
                font.weight: Font.Medium
                color: (root.hasData && root.barLeader && root.barLeader.playable) ? Theme.primary : Theme.widgetTextColor
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    popoutWidth: Theme.buttonHeightM * 8

    popoutContent: Component {
        PopoutComponent {
            id: popout

            property string selectedEffortId: ""
            readonly property var selectedEffort: root.findEffortById(selectedEffortId)

            headerText: "PortWatch VI"
            detailsText: {
                if (root.isFetching && !root.hasData)
                    return "Loading GTA VI PC port tracker…";
                const parts = [];
                if (root.model.updatedAgo)
                    parts.push("Scouted " + root.model.updatedAgo);
                parts.push("4lwayz/portwatch-vi");
                return parts.join(" • ");
            }

            headerActions: Component {
                Row {
                    spacing: Theme.spacingXXS

                    DActionButton {
                        iconName: "refresh"
                        iconColor: root.isFetching ? Theme.primary : Theme.onSurfaceVariant
                        tooltipText: "Refresh data"
                        enabled: !root.isFetching
                        onClicked: root.fetchTrackerData(true)
                    }

                    DActionButton {
                        iconName: "open_in_new"
                        iconColor: Theme.onSurfaceVariant
                        tooltipText: "Open 4lwayz/portwatch-vi on GitHub"
                        onClicked: root.openExternalUrl(root.githubRepoUrl)
                    }
                }
            }

            Connections {
                target: popout.parentPopout
                enabled: popout.parentPopout !== null
                function onShouldBeVisibleChanged() {
                    if (popout.parentPopout.shouldBeVisible) {
                        popout.selectedEffortId = "";
                        root._relativeTick++;
                        root.maybeBackgroundRefresh();
                    }
                }
            }

            Timer {
                id: relativeTimeTimer
                interval: 60 * 1000
                repeat: true
                running: root.hasData && popout.parentPopout !== null && popout.parentPopout.shouldBeVisible
                onTriggered: root._relativeTick++
            }

            RepoListView {
                id: listView
                visible: popout.selectedEffort === null
                width: parent.width
                modelDataObj: root.model
                activeFilter: globalActiveFilter.value || "race"
                isLoading: root.isFetching
                errorText: root.lastError

                onEffortSelected: effortId => {
                    popout.selectedEffortId = effortId;
                    Qt.callLater(() => detailView.resetScroll());
                }

                onFilterChanged: nextFilter => {
                    globalActiveFilter.set(nextFilter);
                }

                onRetryRequested: root.fetchTrackerData(true)
            }

            RepoDetailView {
                id: detailView
                visible: popout.selectedEffort !== null
                width: parent.width
                effort: popout.selectedEffort
                openUrlFn: url => root.openExternalUrl(url)

                onBackRequested: popout.selectedEffortId = ""
            }
        }
    }
}
