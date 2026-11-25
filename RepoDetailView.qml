pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets

Item {
    id: root

    property var effort: null
    property var openUrlFn: null

    signal backRequested

    function resetScroll() {
        detailFlick.contentY = 0;
    }

    implicitHeight: detailOuterCol.implicitHeight

    component MetricTile: StyledRect {
        id: tile
        property string label: ""
        property string value: ""
        property color tileColor: Theme.chipSurface
        property color valueColor: Theme.onSurface

        height: tileCol.implicitHeight + Theme.spacingS * 2
        radius: Theme.cornerRadiusS
        color: tile.tileColor

        Column {
            id: tileCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: Theme.spacingS
            spacing: Theme.spacingXXS

            StyledText {
                text: tile.label
                font.pixelSize: Theme.fontSizeSmall - 2
                color: Theme.onSurfaceVariant
            }

            StyledText {
                width: parent.width
                text: tile.value
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Theme.fontWeightBold
                color: tile.valueColor
                elide: Text.ElideRight
            }
        }
    }

    component BulletCard: StyledRect {
        id: card
        property string title: ""
        property string iconName: ""
        property color accentColor: Theme.primary
        property string emptyText: ""
        property var items: []

        width: detailContentCol.width
        height: cardCol.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadiusM
        color: Theme.cardSurface
        border.width: Theme.outlineWidth
        border.color: Theme.withAlpha(card.accentColor, 0.32)

        Column {
            id: cardCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingXS

                DIcon {
                    name: card.iconName
                    size: Theme.iconSizeSmall + 2
                    color: card.accentColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: card.title
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Theme.fontWeightBold
                    color: Theme.onSurface
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                visible: !card.items || card.items.length === 0
                width: parent.width
                text: card.emptyText
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.onSurfaceVariant
            }

            Repeater {
                model: card.items || []

                delegate: Row {
                    required property string modelData
                    width: cardCol.width
                    spacing: Theme.spacingS

                    Rectangle {
                        id: bulletDot
                        width: Theme.spacingXS + Theme.spacingXXS
                        height: width
                        radius: width / 2
                        color: card.accentColor
                        y: Theme.spacingXS + Theme.spacingXXS
                    }

                    StyledText {
                        width: cardCol.width - bulletDot.width - Theme.spacingS
                        text: modelData
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.onSurface
                        wrapMode: Text.WordWrap
                        lineHeight: 1.25
                    }
                }
            }
        }
    }

    Column {
        id: detailOuterCol
        width: parent.width
        spacing: Theme.spacingS

        Row {
            width: parent.width
            spacing: Theme.spacingS

            StyledRect {
                id: backBtn
                width: backRow.implicitWidth + Theme.spacingM * 2
                height: Theme.buttonHeightXS
                radius: Theme.fullRadius(width, height)
                color: Theme.chipSurface
                border.width: Theme.outlineWidth
                border.color: Theme.outlineVariant

                StateLayer {
                    anchors.fill: parent
                    onClicked: root.backRequested()
                }

                Row {
                    id: backRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DIcon {
                        name: "arrow_back"
                        size: Theme.iconSizeSmall
                        color: Theme.onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: "All repos"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Theme.fontWeightMedium
                        color: Theme.onSurface
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Item {
                width: Math.max(0, parent.width - backBtn.width - openRepoBtn.width - Theme.spacingS * 2)
                height: Theme.outlineWidth
            }

            DButton {
                id: openRepoBtn
                visible: root.effort !== null && root.effort.openUrl.length > 0
                text: "GitHub"
                iconName: "open_in_new"
                variant: "tonal"
                buttonHeight: Theme.buttonHeightXS
                onClicked: {
                    if (root.effort && root.openUrlFn)
                        root.openUrlFn(root.effort.openUrl);
                }
            }
        }

        DFlickable {
            id: detailFlick
            visible: root.effort !== null
            width: parent.width
            height: Math.min(Theme.listItemTwoLineHeight * 6, detailContentCol.implicitHeight)
            contentWidth: width
            contentHeight: detailContentCol.implicitHeight
            clip: true

            Column {
                id: detailContentCol
                width: detailFlick.width
                spacing: Theme.spacingS

                StyledRect {
                    width: parent.width
                    height: overviewCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadiusM
                    color: Theme.cardSurface
                    border.width: Theme.outlineWidth
                    border.color: Theme.outlineVariant

                    Column {
                        id: overviewCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        Row {
                            width: parent.width
                            spacing: Theme.spacingS

                            Column {
                                width: parent.width - detailScoreCol.width - Theme.spacingS
                                spacing: Theme.spacingXXS
                                anchors.verticalCenter: parent.verticalCenter

                                StyledText {
                                    width: parent.width
                                    text: root.effort ? root.effort.name : ""
                                    font.pixelSize: Theme.fontSizeLarge
                                    font.weight: Theme.fontWeightBold
                                    color: Theme.onSurface
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    width: parent.width
                                    text: root.effort ? root.effort.displayRepo : ""
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.onSurfaceVariant
                                    wrapMode: Text.WordWrap
                                }

                                StyledText {
                                    visible: root.effort && root.effort.basedOnText.length > 0
                                    width: parent.width
                                    text: root.effort ? root.effort.basedOnText : ""
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    color: Theme.primary
                                    wrapMode: Text.WordWrap
                                }
                            }

                            Column {
                                id: detailScoreCol
                                width: Math.max(detailPct.implicitWidth, detailStage.implicitWidth)
                                spacing: Theme.spacingXXS
                                anchors.verticalCenter: parent.verticalCenter

                                NumericText {
                                    id: detailPct
                                    anchors.right: parent.right
                                    text: root.effort ? root.effort.scoreText : "0%"
                                    font.pixelSize: Theme.fontSizeXLarge + 2
                                    font.weight: Theme.fontWeightBold
                                    color: root.effort && root.effort.nuked ? Theme.error : Theme.primary
                                }

                                StyledText {
                                    id: detailStage
                                    anchors.right: parent.right
                                    text: root.effort ? root.effort.reachedLabel : ""
                                    font.pixelSize: Theme.fontSizeSmall - 1
                                    font.weight: Theme.fontWeightMedium
                                    color: Theme.onSurfaceVariant
                                }
                            }
                        }

                        ProgressBarTrack {
                            width: parent.width
                            barHeight: Theme.spacingXS + Theme.spacingXXS
                            fraction: root.effort ? root.effort.score / 100 : 0
                            fillColor: root.effort && root.effort.nuked ? Theme.error : Theme.primary
                            showPlayableMark: true
                        }

                        Row {
                            id: metricRow
                            width: parent.width
                            spacing: Theme.spacingXS

                            readonly property real tileW: (width - spacing * 2) / 3

                            MetricTile {
                                width: metricRow.tileW
                                label: "FPS right now"
                                value: root.effort ? root.effort.fpsDetailText : "—"
                                tileColor: root.effort && root.effort.hasFps
                                    ? Theme.withAlpha(Theme.primaryContainer, 0.65)
                                    : Theme.chipSurface
                                valueColor: root.effort && root.effort.hasFps ? Theme.primary : Theme.onSurface
                            }

                            MetricTile {
                                width: metricRow.tileW
                                label: "Stability"
                                value: root.effort ? root.effort.stabilityLabel : "Unknown"
                            }

                            MetricTile {
                                width: metricRow.tileW
                                label: root.effort && root.effort.isPrivate ? "Visibility" : "GitHub Stars"
                                value: root.effort
                                    ? (root.effort.isPrivate ? "Private code" : ("★ " + root.effort.starsText))
                                    : "—"
                            }
                        }

                        Flow {
                            width: parent.width
                            spacing: Theme.spacingXS

                            Repeater {
                                model: {
                                    if (!root.effort)
                                        return [];
                                    const tags = [];
                                    if (root.effort.approach)
                                        tags.push(root.effort.approach);
                                    if (root.effort.target)
                                        tags.push(root.effort.target);
                                    if (root.effort.verification)
                                        tags.push(root.effort.verification);
                                    if (root.effort.pushedAgo)
                                        tags.push("Updated " + root.effort.pushedAgo);
                                    return tags;
                                }

                                delegate: Rectangle {
                                    required property string modelData
                                    width: tagLbl.implicitWidth + Theme.spacingS * 2
                                    height: Math.max(Theme.iconSizeMedium, tagLbl.implicitHeight + Theme.spacingXXS * 2)
                                    radius: Theme.cornerRadiusS
                                    color: Theme.chipSurfaceNested

                                    StyledText {
                                        id: tagLbl
                                        anchors.centerIn: parent
                                        text: modelData
                                        font.pixelSize: Theme.fontSizeSmall - 2
                                        color: Theme.onSurfaceVariant
                                    }
                                }
                            }
                        }

                        StyledText {
                            visible: root.effort && root.effort.summary.length > 0
                            width: parent.width
                            text: root.effort ? root.effort.summary : ""
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.onSurfaceVariant
                            wrapMode: Text.WordWrap
                            lineHeight: 1.25
                        }
                    }
                }

                StyledRect {
                    visible: root.effort && root.effort.nuked
                    width: parent.width
                    height: nukeCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadiusM
                    color: Theme.errorContainer

                    Column {
                        id: nukeCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Row {
                            spacing: Theme.spacingXS

                            DIcon {
                                name: "block"
                                size: Theme.iconSizeSmall
                                color: Theme.onErrorContainer
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            StyledText {
                                text: "Taken offline" + (root.effort && root.effort.nukedAt ? " (" + root.effort.nukedAt + ")" : "")
                                font.pixelSize: Theme.fontSizeSmall
                                font.weight: Theme.fontWeightBold
                                color: Theme.onErrorContainer
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        StyledText {
                            visible: root.effort && root.effort.nukedNote.length > 0
                            width: parent.width
                            text: root.effort ? root.effort.nukedNote : ""
                            font.pixelSize: Theme.fontSizeSmall - 1
                            color: Theme.onErrorContainer
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                BulletCard {
                    title: "Pros · What works"
                    iconName: "check_circle"
                    accentColor: Theme.success
                    emptyText: "No working highlights recorded yet."
                    items: root.effort ? root.effort.pros : []
                }

                BulletCard {
                    title: "Cons · What's blocking"
                    iconName: "error_outline"
                    accentColor: Theme.warning
                    emptyText: "No blockers recorded yet."
                    items: root.effort ? root.effort.cons : []
                }

                StyledRect {
                    visible: root.effort && root.effort.breakdownRows && root.effort.breakdownRows.length > 0
                    width: parent.width
                    height: bdCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadiusM
                    color: Theme.cardSurface
                    border.width: Theme.outlineWidth
                    border.color: Theme.outlineVariant

                    Column {
                        id: bdCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingS

                        StyledText {
                            text: root.effort && root.effort.breakdownKind === "tracks"
                                ? "Playable tracks (50–100%)"
                                : "Groundwork breakdown (0–10%)"
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Theme.fontWeightBold
                            color: Theme.onSurfaceVariant
                        }

                        Repeater {
                            model: root.effort ? root.effort.breakdownRows : []

                            delegate: Column {
                                required property var modelData
                                width: parent.width
                                spacing: Theme.spacingXXS

                                Row {
                                    width: parent.width

                                    StyledText {
                                        width: parent.width * 0.45
                                        text: modelData.label
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.onSurface
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        width: parent.width * 0.55
                                        text: modelData.valueText
                                        font.pixelSize: Theme.fontSizeSmall - 1
                                        color: Theme.onSurfaceVariant
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideRight
                                    }
                                }

                                ProgressBarTrack {
                                    width: parent.width
                                    barHeight: Theme.spacingXS
                                    fraction: modelData.fraction
                                    fillColor: root.effort && root.effort.breakdownKind === "tracks" ? Theme.primary : Theme.secondary
                                }
                            }
                        }
                    }
                }

                DButton {
                    visible: root.effort && root.effort.proofUrl.length > 0
                    width: parent.width
                    text: root.effort ? root.effort.proofLabel : "Watch proof"
                    iconName: "play_circle"
                    variant: "outlined"
                    onClicked: {
                        if (root.effort && root.openUrlFn)
                            root.openUrlFn(root.effort.proofUrl);
                    }
                }
            }
        }
    }
}
