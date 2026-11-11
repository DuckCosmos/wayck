import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 7

    hoverScale: 1

    signal expandRequested(var sourceItem, var surfaceData)

    readonly property var settingsItems: [
        { id: "hyprland", symbol: "H" },
        { id: "displays", symbol: "▣" },
        { id: "network", symbol: "⌁" },
        { id: "audio", symbol: "♫" },
        { id: "bluetooth", symbol: "ᛒ" },
        { id: "appearance", symbol: "◈" },
        { id: "system", symbol: "⚙" },
        { id: "monitor", symbol: "▥" }
    ]

    readonly property var powerItems: [
        { id: "lock", symbol: "▣" },
        { id: "suspend", symbol: "☾" },
        { id: "reboot", symbol: "↻" },
        { id: "poweroff", symbol: "⏻" },
        { id: "logout", symbol: "⇥" }
    ]

    readonly property var confirmActions: ["suspend", "reboot", "poweroff", "logout"]

    function togglePage(pageName) {
        if (popup.visible && popup.page === pageName) {
            popup.visible = false
            return
        }

        popup.page = pageName
        popup.pendingAction = ""
        popup.visible = true
    }

    function actionTitle(action) {
        return confirmActions.includes(action)
            ? I18n.t("usermenu.confirm." + action + ".title")
            : I18n.t("usermenu.confirm.default.title")
    }

    function actionDescription(action) {
        return confirmActions.includes(action)
            ? I18n.t("usermenu.confirm." + action + ".description")
            : ""
    }

    Item {
        id: profileButton

        implicitWidth: profileRow.implicitWidth + 2
        implicitHeight: 28

        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight

        RowLayout {
            id: profileRow

            anchors.fill: parent
            spacing: 7

            Item {
                Layout.preferredWidth: 20
                Layout.preferredHeight: 20

                Rectangle {
                    width: 7
                    height: 7
                    radius: 4
                    color: Theme.surfaceForeground
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                }

                Rectangle {
                    width: 16
                    height: 8
                    radius: 5
                    color: Theme.surfaceForeground
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                }
            }

            Text {
                text: UserController.username
                color: Theme.surfaceForeground
                font.pixelSize: 12
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.expandRequested(root, null)
        }
    }

    Rectangle {
        id: powerButton

        Layout.preferredWidth: 28
        Layout.preferredHeight: 28

        radius: 9
        color: powerMouse.containsMouse
            ? Theme.primary
            : Qt.darker(Theme.surfaceContainer, 1.05)

        Text {
            anchors.centerIn: parent
            text: "⏻"
            anchors.verticalCenterOffset: 4
            color: powerMouse.containsMouse
                ? Theme.onPrimary
                : Theme.primary

            font.pixelSize: 19
            font.bold: true
        }

        HoverHandler {
            enabled: root.hoverEnabled
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

            onHoveredChanged: {
                QsWindow.window.morph.setSourceHovered(root, hovered)

                if (hovered)
                    expandTimer.restart()
                else
                    expandTimer.stop()
            }
        }

        Timer {
            id: expandTimer

            interval: Motion.hoverDwellDuration
            repeat: false

            onTriggered: {
                root.expandRequested(root, null)
            }
        }

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.togglePage("power")
        }
    }
}
