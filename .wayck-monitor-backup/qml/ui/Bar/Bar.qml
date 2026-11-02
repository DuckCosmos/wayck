import QtQuick
import Quickshell
import Quickshell.Wayland

import "../../services"
import "components" as Components

PanelWindow {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string backend: Quickshell.shellPath("wayck-backend")

    property color cPrimary: colorsData.primary || "#ffb59b"
    property color cOnPrimary: colorsData.on_primary || "#55200a"
    property color cSurfaceContainer: colorsData.surface_container_high || "#322824"
    property color cOnSurface: colorsData.on_surface || "#f1dfd9"
    property color cOutline: colorsData.outline || "#a08d86"
    property var colorsData: ({})

    signal dismissed()

    function sourceFor(id) {
        switch (id) {
        case "workspaces": return Qt.resolvedUrl("modules/Workspaces.qml")
        case "player": return Qt.resolvedUrl("modules/Player.qml")
        case "audio": return Qt.resolvedUrl("modules/Audio.qml")
        case "clock": return Qt.resolvedUrl("modules/Clock.qml")
        case "tray": return Qt.resolvedUrl("modules/Tray.qml")
        default: return ""
        }
    }

    color: "transparent"
    implicitHeight: 45
    exclusiveZone: 45

    WlrLayershell.namespace: "wayck-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 8
        left: 8
        right: 8
    }

    Item {
        anchors.fill: parent

        // LEFT
        Row {
            id: leftSection
            width: childrenRect.width
            height: childrenRect.height
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: BarConfig.leftModules

                delegate: Components.ModuleSlot {
                    required property var modelData
                    moduleId: modelData
                    sourceUrl: root.sourceFor(modelData)
                    cPrimary: root.cPrimary
                    cOnPrimary: root.cOnPrimary
                    cSurfaceContainer: root.cSurfaceContainer
                    cOnSurface: root.cOnSurface
                    cOutline: root.cOutline
                }
            }
        }

        // CENTER
        Row {
            id: centerSection
            width: childrenRect.width
            height: childrenRect.height
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: BarConfig.centerModules

                delegate: Components.ModuleSlot {
                    required property var modelData
                    moduleId: modelData
                    sourceUrl: root.sourceFor(modelData)
                    cPrimary: root.cPrimary
                    cOnPrimary: root.cOnPrimary
                    cSurfaceContainer: root.cSurfaceContainer
                    cOnSurface: root.cOnSurface
                    cOutline: root.cOutline
                }
            }
        }

        // RIGHT
        Row {
            id: rightSection
            width: childrenRect.width
            height: childrenRect.height
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Repeater {
                model: BarConfig.rightModules

                delegate: Components.ModuleSlot {
                    required property var modelData
                    moduleId: modelData
                    sourceUrl: root.sourceFor(modelData)
                    cPrimary: root.cPrimary
                    cOnPrimary: root.cOnPrimary
                    cSurfaceContainer: root.cSurfaceContainer
                    cOnSurface: root.cOnSurface
                    cOutline: root.cOutline
                }
            }
        }
    }
}
