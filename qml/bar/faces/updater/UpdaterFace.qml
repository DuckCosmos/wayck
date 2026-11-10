import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

BarCard {
    id: root

    // Keep morph capture geometry aligned with the unscaled source anchor.
    hoverScale: 1

    signal expandRequested(var sourceItem, var surfaceData, var windowRef)

    visible: UpdateController.updateAvailable
    implicitWidth: UpdateController.updateAvailable ? 34 : 0
    implicitHeight: 36

    horizontalPadding: 5
    verticalPadding: 3
    contentSpacing: 0
    minimumHeight: 36
    cornerRadius: 9

    function requestExpand(reason): void {
        if (!UpdateController.updateAvailable || MorphController.active)
            return

        if (Quickshell.env("WAYCK_DEBUG") === "1")
            console.log("[WAYCK INPUT] updater emit expandRequested:", reason)

        expandRequested(root, null, QsWindow.window)
    }

    Item {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 26

        Text {
            anchors.centerIn: parent
            text: "󰇚"
            color: root.hovered ? Theme.primary : Theme.surfaceForeground
            font.pixelSize: 19

            Behavior on color {
                ColorAnimation {
                    duration: Motion.colorDuration
                    easing.type: Motion.standard
                }
            }
        }

        HoverHandler {
            enabled: root.hoverEnabled
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onHoveredChanged: {
                MorphController.setSourceHovered(root, hovered)

                if (hovered)
                    openTimer.restart()
                else
                    openTimer.stop()
            }
        }

        Timer {
            id: openTimer
            interval: Motion.hoverDwellDuration
            repeat: false
            onTriggered: root.requestExpand("hover dwell")
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onClicked: root.requestExpand("click")
        }
    }
}
