import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "."

RowLayout {
    id: root

    property color cPrimary: "#ffb59b"
    property color cOnPrimary: "#55200a"
    property color cSurfaceContainer: "#322824"
    property color cOnSurface: "#f1dfd9"
    property color cOutline: "#a08d86"

    spacing: 5

    Repeater {
        model: [1, 2, 3, 4, 5]

        delegate: BarCard {
            id: workspaceCard
            required property int modelData

            property bool active: Hyprland.focusedWorkspace !== null
                && Hyprland.focusedWorkspace.id === modelData

            cPrimary: root.cPrimary
            cOnPrimary: root.cOnPrimary
            cSurfaceContainer: root.cSurfaceContainer
            cOnSurface: root.cOnSurface
            cOutline: root.cOutline

            highlighted: active
            implicitWidth: 34
            implicitHeight: 34
            scale: active ? 1.10 : 1.0
            z: active ? 1 : 0
            transformOrigin: Item.Center

            Behavior on scale {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.OutCubic
                }
            }

            horizontalPadding: 4
            verticalPadding: 4

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                Text {
                    anchors.fill: parent
                    text: String(workspaceCard.modelData)
                    color: workspaceCard.active ? root.cOnPrimary : root.cOnSurface

                    Behavior on color {
                        ColorAnimation {
                            duration: 180
                            easing.type: Easing.OutCubic
                            }
                    }


                    font.pixelSize: 13
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + workspaceCard.modelData)
                }
            }
        }
    }
}
