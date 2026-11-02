import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property color cPrimary: "#ffb59b"
    property color cOnPrimary: "#55200a"
    property color cSurfaceContainer: "#322824"
    property color cOnSurface: "#f1dfd9"
    property color cOutline: "#a08d86"

    property bool highlighted: false
    property string section: "center"

    property int cornerRadius: 12
    property int horizontalPadding: 8
    property int verticalPadding: 4
    property int minimumHeight: 34

    default property alias contentData: content.data

    readonly property real radius: Math.min(
        cornerRadius,
        width / 2,
        height / 2
    )

    implicitWidth: content.implicitWidth + horizontalPadding * 2

    implicitHeight: Math.max(
        minimumHeight,
        content.implicitHeight + verticalPadding * 2
    )

    Rectangle {
        anchors.fill: parent

        radius: root.radius

        color: root.highlighted
            ? Qt.darker(root.cOutline, 0.85)
            : root.cSurfaceContainer

        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent

        color: "transparent"
        radius: root.radius

        border.width: 1
        border.color: root.highlighted
            ? root.cSurfaceContainer
            : Qt.darker(root.cOutline, 1.15)

        antialiasing: true
    }

    RowLayout {
        id: content

        anchors.fill: parent

        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.verticalPadding
        anchors.bottomMargin: root.verticalPadding

        spacing: 6
    }
}