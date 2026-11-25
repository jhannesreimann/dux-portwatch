pragma ComponentBehavior: Bound

import QtQuick
import qs.Common
import qs.DCommon.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "portwatchVi"

    property var popoutService: null

    StyledText {
        width: parent.width
        text: "PortWatch VI"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Tracks GTA VI PC port progress from github.com/4lwayz/portwatch-vi."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: displayCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.chipSurface

        Column {
            id: displayCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Bar Display"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }

            SelectionSetting {
                settingKey: "barDisplayMode"
                label: "Bar Label Style"
                description: "Choose what appears next to the icon in the top bar"
                options: [
                    { label: "Repo + Percentage (e.g. ZETTROX 64.2%)", value: "nameAndPct" },
                    { label: "Short Tag + Percentage (e.g. VI 64.2%)", value: "compact" },
                    { label: "Percentage Only (e.g. 64.2%)", value: "pctOnly" }
                ]
                defaultValue: "nameAndPct"
            }

            ToggleSetting {
                settingKey: "showBarFps"
                label: "Show FPS in Top Bar"
                description: "Append the top repo's reported FPS in the bar pill when above 0"
                defaultValue: false
            }

            ToggleSetting {
                settingKey: "includePrivateInTop"
                label: "Include Private Builds in Top Bar"
                description: "Allow unlinked private builds to claim the #1 bar slot if they score highest"
                defaultValue: false
            }
        }
    }

    StyledRect {
        width: parent.width
        height: sourceCol.implicitHeight + Theme.spacingL * 2
        radius: Theme.cornerRadius
        color: Theme.chipSurface

        Column {
            id: sourceCol
            anchors.fill: parent
            anchors.margins: Theme.spacingL
            spacing: Theme.spacingM

            StyledText {
                text: "Data & Sync"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Theme.fontWeightMedium
                color: Theme.surfaceText
            }

            SliderSetting {
                settingKey: "refreshIntervalMinutes"
                label: "Refresh Interval"
                description: "How often to poll 4lwayz/portwatch-vi for updated scores (upstream scout runs every 3h)"
                defaultValue: 15
                minimum: 5
                maximum: 180
                unit: " min"
            }
        }
    }
}
