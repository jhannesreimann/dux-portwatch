pragma ComponentBehavior: Bound

import QtQuick
import qs.Common

Rectangle {
    id: root

    property real fraction: 0
    property color fillColor: Theme.primary
    property color trackColor: Theme.withAlpha(Theme.outlineVariant, 0.45)
    property bool showPlayableMark: false
    property real barHeight: 6

    readonly property real clampedFraction: Math.max(0, Math.min(1, Number(fraction) || 0))

    implicitHeight: barHeight
    height: barHeight
    radius: height / 2
    color: trackColor
    clip: true

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: Math.max(root.clampedFraction > 0 ? parent.height : 0, parent.width * root.clampedFraction)
        radius: parent.radius
        color: root.fillColor

        Behavior on width {
            enabled: (typeof SettingsData === "undefined" || !SettingsData.reduceMotion) && Theme.mediumDuration > 0
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.standardEasing
            }
        }
    }

    Rectangle {
        visible: root.showPlayableMark
        x: Math.round(parent.width * 0.5 - width / 2)
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Theme.withAlpha(Theme.onSurface, 0.35)
    }
}
