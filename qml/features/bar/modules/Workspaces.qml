import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import "."
import "../../../core"

RowLayout {
    id: root

    spacing: 5

    Repeater {
        model: [1, 2, 3, 4, 5]

        delegate: BarCard {
            id: workspaceCard
            required property int modelData

            property bool active: Hyprland.focusedWorkspace !== null
                && Hyprland.focusedWorkspace.id === modelData

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
                    color: workspaceCard.active ? Theme.onPrimary : Theme.onSurface

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
