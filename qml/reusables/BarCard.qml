import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: root

    property real compactness: 0

    property bool highlighted: false
    property string section: "center"
    property real emphasisScale: 1

    property int contentSpacing: 6
    property int cornerRadius: 6
    property int horizontalPadding: 8
    property int verticalPadding: 4
    property int minimumHeight: 34

    property bool showBackground: true
    property bool showBorder: true

    property bool hoverEnabled: true
    property real hoverScale: 1.035
    property real hoverRadiusBoost: 3
    property bool hovered: false

    onHoverEnabledChanged: {
        if (!hoverEnabled)
            hovered = false
    }

    default property alias contentData: content.data

    readonly property real effectiveHorizontalPadding:
        horizontalPadding + (5 - horizontalPadding) * compactness

    readonly property real effectiveVerticalPadding:
        verticalPadding + (2 - verticalPadding) * compactness

    readonly property real effectiveContentSpacing:
        contentSpacing + (4 - contentSpacing) * compactness

    readonly property real effectiveMinimumHeight:
        minimumHeight + (32 - minimumHeight) * compactness

    readonly property real radius: Math.min(
        cornerRadius,
        width / 2,
        height / 2
    )

    implicitWidth:
        content.implicitWidth + effectiveHorizontalPadding * 2

    implicitHeight: Math.max(
        effectiveMinimumHeight,
        content.implicitHeight + effectiveVerticalPadding * 2
    )

    scale: emphasisScale * (hoverEnabled && hovered ? hoverScale : 1)
    transformOrigin: Item.Center

    Behavior on scale {
        NumberAnimation {
            duration: Motion.hoverDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.hovered ? Motion.hoverEnterCurve : Motion.hoverExitCurve
        }
    }

    HoverHandler {
        enabled: root.hoverEnabled
        onHoveredChanged: root.hovered = hovered
    }

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width / 2, height / 2,
                         root.radius + (root.hovered ? root.hoverRadiusBoost : 0))

        color: root.highlighted
            ? Qt.darker(Theme.outline, 0.85)
            : (root.hovered
                ? Qt.lighter(Theme.surfaceContainer, 1.08)
                : Qt.darker(Theme.surfaceContainer, 1.75))

        antialiasing: true
        visible: root.showBackground

        Behavior on color {
            ColorAnimation { duration: Motion.colorDuration; easing.type: Motion.standard }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Motion.hoverDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.morphCurve
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: Math.min(width / 2, height / 2,
                         root.radius + (root.hovered ? root.hoverRadiusBoost : 0))

        border.width: 1
        border.color: root.highlighted
            ? Theme.surfaceContainer
            : (root.hovered ? Theme.primary : Qt.darker(Theme.outline, 1.15))

        antialiasing: true
        visible: root.showBorder

        Behavior on border.color {
            ColorAnimation { duration: Motion.colorDuration; easing.type: Motion.standard }
        }
        Behavior on radius {
            NumberAnimation {
                duration: Motion.hoverDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.morphCurve
            }
        }
    }

    RowLayout {
        id: content

        anchors.fill: parent

        anchors.leftMargin: root.effectiveHorizontalPadding
        anchors.rightMargin: root.effectiveHorizontalPadding
        anchors.topMargin: root.effectiveVerticalPadding
        anchors.bottomMargin: root.effectiveVerticalPadding

        spacing: root.effectiveContentSpacing
    }
}
