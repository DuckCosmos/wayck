
import QtQuick
import QtQuick.Layouts
import "../../../core"

Item {
    id: root

    property real compactness: 0

    property bool highlighted: false
    property string section: "center"

    property int contentSpacing: 6
    property int cornerRadius: 12
    property int horizontalPadding: 8
    property int verticalPadding: 4
    property int minimumHeight: 34

    property bool showBackground: true
    property bool showBorder: true

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

    Rectangle {
        anchors.fill: parent
        radius: root.radius

        color: root.highlighted
            ? Qt.darker(Theme.outline, 0.85)
            : Qt.darker(Theme.surfaceContainer, 1.75)

        antialiasing: true
        visible: root.showBackground
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.radius

        border.width: 1
        border.color: root.highlighted
            ? Theme.surfaceContainer
            : Qt.darker(Theme.outline, 1.15)

        antialiasing: true
        visible: root.showBorder
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
