pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var modelDataObj: null
    property string activeFilter: "race"
    property bool isLoading: false
    property string errorText: ""

    signal effortSelected(string effortId)
    signal filterChanged(string nextFilter)
    signal retryRequested

    readonly property var currentItems: {
        if (!modelDataObj || !modelDataObj.valid)
            return [];
        if (activeFilter === "all")
            return modelDataObj.allTrackedItems || [];
        if (activeFilter === "watchlist")
            return modelDataObj.watchlistItems || [];
        return modelDataObj.raceItems || [];
    }

    readonly property var leader: modelDataObj && modelDataObj.valid ? modelDataObj.barLeader : null
    readonly property var topOverall: modelDataObj && modelDataObj.valid ? modelDataObj.topOverall : null
    readonly property bool showPrivateLeadNote: {
        if (!leader || !topOverall)
            return false;
        return leader.id !== topOverall.id && topOverall.score > leader.score;
    }

    readonly property int raceCount: modelDataObj && modelDataObj.raceItems ? modelDataObj.raceItems.length : 0
    readonly property int allCount: modelDataObj && modelDataObj.allTrackedItems ? modelDataObj.allTrackedItems.length : 0
    readonly property int watchlistCount: modelDataObj && modelDataObj.watchlistItems ? modelDataObj.watchlistItems.length : 0

    implicitHeight: layoutCol.implicitHeight

    component FilterChip: StyledRect {
        id: chip
        required property var modelData
        readonly property bool selected: root.activeFilter === modelData.key

        width: (filterRow.width - filterRow.spacing * 2) / 3
        height: Theme.buttonHeightXS
        radius: Theme.fullRadius(width, height)
        color: chip.selected ? Theme.selectedContainer : Theme.chipSurface
        border.width: Theme.outlineWidth
        border.color: chip.selected ? Theme.withAlpha(Theme.primary, 0.45) : Theme.outlineVariant

        StateLayer {
            anchors.fill: parent
            onClicked: root.filterChanged(chip.modelData.key)
        }

        StyledText {
            anchors.centerIn: parent
            text: chip.modelData.label
            font.pixelSize: Theme.fontSizeSmall
            font.weight: chip.selected ? Theme.fontWeightMedium : Font.Normal
            color: chip.selected ? Theme.onSelectedContainer : Theme.onSurfaceVariant
            elide: Text.ElideRight
        }
    }

    component EffortRow: StyledRect {
        id: rowCard
        required property var modelData
        required property int index

        readonly property var effort: modelData
        readonly property bool isTop: effort.rank === 1 && !effort.nuked
        readonly property color barAccent: effort.nuked
            ? Theme.error
            : (effort.playable ? Theme.primary : Theme.secondary)

        width: listColumn.width
        height: rowInner.implicitHeight + Theme.spacingS * 2 + Theme.spacingXS
        radius: Theme.cornerRadiusM
        color: isTop ? Theme.withAlpha(Theme.primaryContainer, 0.38) : Theme.chipSurface
        border.width: Theme.outlineWidth
        border.color: isTop ? Theme.withAlpha(Theme.primary, 0.35) : Theme.outlineVariant

        StateLayer {
            anchors.fill: parent
            onClicked: root.effortSelected(rowCard.effort.id)
        }

        Column {
            id: rowInner
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingS
            anchors.topMargin: Theme.spacingS
            spacing: Theme.spacingXS

            Row {
                width: parent.width
                spacing: Theme.spacingS

                Rectangle {
                    id: rankBox
                    width: Theme.iconSize + Theme.spacingXS
                    height: Theme.iconSize + Theme.spacingXS
                    radius: Theme.cornerRadiusS
                    anchors.verticalCenter: parent.verticalCenter
                    color: rowCard.effort.nuked
                        ? Theme.errorContainer
                        : (rowCard.effort.rank > 0 && rowCard.effort.rank <= 3
                            ? Theme.primaryContainer
                            : Theme.chipSurfaceNested)

                    StyledText {
                        visible: !rowCard.effort.nuked && rowCard.effort.rank > 0
                        anchors.centerIn: parent
                        text: "#" + rowCard.effort.rank
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightBold
                        color: rowCard.effort.rank <= 3 ? Theme.onPrimaryContainer : Theme.onSurfaceVariant
                    }

                    DIcon {
                        visible: rowCard.effort.nuked
                        anchors.centerIn: parent
                        name: "block"
                        size: Theme.iconSizeSmall
                        color: Theme.onErrorContainer
                    }
                }

                Column {
                    width: parent.width - rankBox.width - rightStats.width - Theme.spacingS * 2
                    spacing: Theme.spacingXXS
                    anchors.verticalCenter: parent.verticalCenter

                    Row {
                        width: parent.width
                        spacing: Theme.spacingXS

                        StyledText {
                            text: rowCard.effort.name
                            font.pixelSize: Theme.fontSizeMedium
                            font.weight: Theme.fontWeightMedium
                            color: Theme.onSurface
                            elide: Text.ElideRight
                            width: Math.min(implicitWidth, parent.width - (privateBadge.visible ? privateBadge.width + Theme.spacingXS : 0))
                        }

                        Rectangle {
                            id: privateBadge
                            visible: rowCard.effort.isPrivate
                            width: privIcon.width + privLbl.implicitWidth + Theme.spacingXS * 2
                            height: Math.max(privIcon.height, privLbl.implicitHeight) + Theme.spacingXS
                            radius: Theme.cornerRadiusS
                            color: Theme.secondaryContainer
                            anchors.verticalCenter: parent.verticalCenter

                            Row {
                                anchors.centerIn: parent
                                spacing: Theme.spacingXXS

                                DIcon {
                                    id: privIcon
                                    name: "lock"
                                    size: Theme.iconSizeSmall
                                    color: Theme.onSecondaryContainer
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                StyledText {
                                    id: privLbl
                                    text: "Private"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onSecondaryContainer
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }

                    StyledText {
                        width: parent.width
                        text: (rowCard.effort.isPrivate ? "Private build" : rowCard.effort.repo)
                            + " • " + rowCard.effort.reachedLabel
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurfaceVariant
                        elide: Text.ElideRight
                    }
                }

                Row {
                    id: rightStats
                    spacing: Theme.spacingXS
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        visible: rowCard.effort.hasFps
                        width: fpsRowText.implicitWidth + Theme.spacingS
                        height: Math.max(Theme.iconSizeMedium, fpsRowText.implicitHeight + Theme.spacingXXS * 2)
                        radius: Theme.cornerRadiusS
                        color: Theme.withAlpha(Theme.primary, 0.14)
                        anchors.verticalCenter: parent.verticalCenter

                        StyledText {
                            id: fpsRowText
                            anchors.centerIn: parent
                            text: rowCard.effort.fpsText
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightMedium
                            color: Theme.primary
                        }
                    }

                    NumericText {
                        text: rowCard.effort.scoreText
                        font.pixelSize: Theme.fontSizeMedium
                        font.weight: Theme.fontWeightBold
                        color: rowCard.effort.nuked
                            ? Theme.onSurfaceVariant
                            : (rowCard.effort.playable ? Theme.primary : Theme.onSurface)
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    DIcon {
                        name: "chevron_right"
                        size: Theme.iconSizeSmall
                        color: Theme.onSurfaceVariant
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            ProgressBarTrack {
                width: parent.width
                barHeight: Theme.spacingXS
                fraction: rowCard.effort.score / 100
                fillColor: rowCard.barAccent
            }
        }
    }

    Column {
        id: layoutCol
        width: parent.width
        spacing: Theme.spacingS

        StyledRect {
            id: heroCard
            visible: root.leader !== null
            width: parent.width
            height: heroInner.implicitHeight + Theme.spacingM * 2
            radius: Theme.cornerRadiusM
            color: Theme.cardSurface
            border.width: Theme.outlineWidth
            border.color: Theme.withAlpha(Theme.primary, 0.35)

            StateLayer {
                anchors.fill: parent
                tooltipText: "View pros & cons for " + (root.leader ? root.leader.name : "")
                onClicked: {
                    if (root.leader)
                        root.effortSelected(root.leader.id);
                }
            }

            Column {
                id: heroInner
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Theme.spacingM
                spacing: Theme.spacingS

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    Column {
                        width: parent.width - heroScoreCol.width - Theme.spacingS
                        spacing: Theme.spacingXXS
                        anchors.verticalCenter: parent.verticalCenter

                        Row {
                            width: parent.width
                            spacing: Theme.spacingXS

                            StyledText {
                                text: "TOP REPO"
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                visible: root.leader !== null
                                text: "• " + (root.leader ? root.leader.reachedLabel : "")
                                font.pixelSize: Theme.fontSizeSmall
                                color: Theme.onSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            width: parent.width
                            text: root.leader ? root.leader.name : ""
                            font.pixelSize: Theme.fontSizeLarge
                            font.weight: Theme.fontWeightBold
                            color: Theme.onSurface
                            elide: Text.ElideRight
                        }

                        StyledText {
                            width: parent.width
                            text: root.leader ? root.leader.displayRepo : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onSurfaceVariant
                            elide: Text.ElideRight
                        }
                    }

                    Column {
                        id: heroScoreCol
                        width: Math.max(heroPct.implicitWidth, heroFpsRow.implicitWidth)
                        spacing: Theme.spacingXXS
                        anchors.verticalCenter: parent.verticalCenter

                        NumericText {
                            id: heroPct
                            anchors.right: parent.right
                            text: root.leader ? root.leader.scoreText : "0%"
                            font.pixelSize: Theme.fontSizeXLarge
                            font.weight: Theme.fontWeightBold
                            color: Theme.primary
                        }

                        Row {
                            id: heroFpsRow
                            anchors.right: parent.right
                            spacing: Theme.spacingXS

                            Rectangle {
                                visible: root.leader && root.leader.hasFps
                                width: heroFpsLabel.implicitWidth + Theme.spacingS
                                height: heroFpsLabel.implicitHeight + Theme.spacingXS
                                radius: Theme.cornerRadiusS
                                color: Theme.primaryContainer

                                StyledText {
                                    id: heroFpsLabel
                                    anchors.centerIn: parent
                                    text: root.leader ? root.leader.fpsText : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.onPrimaryContainer
                                }
                            }

                            DIcon {
                                name: "chevron_right"
                                size: Theme.iconSizeSmall
                                color: Theme.onSurfaceVariant
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                ProgressBarTrack {
                    width: parent.width
                    barHeight: Theme.spacingXS + Theme.spacingXXS
                    fraction: root.leader ? root.leader.score / 100 : 0
                    showPlayableMark: true
                }

                StyledText {
                    visible: root.showPrivateLeadNote
                    width: parent.width
                    text: root.topOverall
                        ? ("Private build leading overall: " + root.topOverall.name + " (" + root.topOverall.scoreText + ", " + root.topOverall.fpsText + ")")
                        : ""
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                    elide: Text.ElideRight
                }
            }
        }

        Row {
            id: filterRow
            width: parent.width
            spacing: Theme.spacingXS

            Repeater {
                model: [
                    { key: "race", label: "Public (" + root.raceCount + ")" },
                    { key: "all", label: "All (" + root.allCount + ")" },
                    { key: "watchlist", label: "Watchlist (" + root.watchlistCount + ")" }
                ]

                delegate: FilterChip {}
            }
        }

        StyledRect {
            visible: root.errorText.length > 0
            width: parent.width
            height: errRow.implicitHeight + Theme.spacingS * 2
            radius: Theme.cornerRadiusM
            color: Theme.errorContainer

            Row {
                id: errRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.margins: Theme.spacingS
                spacing: Theme.spacingS

                DIcon {
                    name: "warning"
                    size: Theme.iconSizeSmall
                    color: Theme.onErrorContainer
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    width: parent.width - Theme.iconSizeSmall - retryBtn.width - Theme.spacingS * 2
                    text: root.errorText
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onErrorContainer
                    wrapMode: Text.WordWrap
                    anchors.verticalCenter: parent.verticalCenter
                }

                DButton {
                    id: retryBtn
                    text: "Retry"
                    variant: "text"
                    buttonHeight: Theme.buttonHeightXS
                    onClicked: root.retryRequested()
                }
            }
        }

        StyledRect {
            visible: root.isLoading && (!root.modelDataObj || !root.modelDataObj.valid)
            width: parent.width
            height: Theme.listItemTwoLineHeight * 2
            radius: Theme.cornerRadiusM
            color: Theme.cardSurface

            Column {
                anchors.centerIn: parent
                spacing: Theme.spacingS

                DSpinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    size: Theme.iconSize
                    color: Theme.primary
                    running: parent.parent.visible
                }

                StyledText {
                    text: "Fetching 4lwayz/portwatch-vi…"
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.onSurfaceVariant
                }
            }
        }

        StyledRect {
            visible: !root.isLoading && root.modelDataObj && root.modelDataObj.valid && root.currentItems.length === 0
            width: parent.width
            height: Theme.menuItemHeight * 2
            radius: Theme.cornerRadiusM
            color: Theme.cardSurface

            StyledText {
                anchors.centerIn: parent
                text: "No repositories in this view."
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }
        }

        DFlickable {
            id: listFlick
            visible: root.currentItems.length > 0
            width: parent.width
            height: Math.min(Theme.buttonHeightM * 5 + Theme.spacingXL, listColumn.implicitHeight)
            contentWidth: width
            contentHeight: listColumn.implicitHeight
            clip: true

            Column {
                id: listColumn
                width: listFlick.width
                spacing: Theme.spacingXS

                Repeater {
                    model: root.currentItems

                    delegate: EffortRow {}
                }
            }
        }
    }
}
