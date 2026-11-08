import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 7

    // Textos em usermenu.settings.<id>.title/subtitle e usermenu.power.<id>.title/subtitle.
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
                    color: Theme.onSurface
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 1
                }

                Rectangle {
                    width: 16
                    height: 8
                    radius: 5
                    color: Theme.onSurface
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                }
            }

            Text {
                text: UserController.username
                color: Theme.onSurface
                font.pixelSize: 12
                font.bold: true
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.togglePage("home")
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

        MouseArea {
            id: powerMouse
            anchors.fill: parent
            hoverEnabled: true
            onClicked: root.togglePage("power")
        }
    }

    PopupWindow {
        id: popup

        property string page: "home"
        property string pendingAction: ""

        anchor.item: root
        anchor.edges: Edges.Bottom | Edges.Right
        anchor.gravity: Edges.Bottom | Edges.Left

        width: 360
        height: page === "home" ? 500
              : page === "power" ? 410
              : 280

        visible: false
        grabFocus: true
        color: "transparent"

        Item {
            anchors.fill: parent

            // Idiomas RTL (árabe, persa): espelha o painel.
            LayoutMirroring.enabled: I18n.rtl
            LayoutMirroring.childrenInherit: true

            Rectangle {
                anchors.fill: parent

                radius: 18
                color: Theme.surfaceContainer
                border.width: 1
                border.color: Qt.darker(Theme.outline, 1.15)

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 15
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 11

                        Rectangle {
                            Layout.preferredWidth: 46
                            Layout.preferredHeight: 46
                            radius: 15
                            color: Theme.primary

                            Text {
                                anchors.centerIn: parent
                                text: UserController.username.length > 0
                                    ? UserController.username
                                        .substring(0, 1).toUpperCase()
                                    : "?"

                                color: Theme.onPrimary
                                font.pixelSize: 23
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: UserController.username
                                color: Theme.onSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: UserController.hostname
                                    + "  ·  " + UserController.desktop

                                color: Theme.outline
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }

                        Text {
                            text: "WAYCK"
                            color: Theme.primary
                            font.pixelSize: 10
                            font.bold: true
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 7
                        visible: popup.page !== "confirm"

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            radius: 9
                            color: popup.page === "home"
                                ? Theme.primary
                                : Qt.darker(Theme.surfaceContainer, 1.08)

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("usermenu.tabs.control")
                                color: popup.page === "home"
                                    ? Theme.onPrimary
                                    : Theme.onSurface

                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: popup.page = "home"
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 34

                            radius: 9
                            color: popup.page === "power"
                                ? Theme.primary
                                : Qt.darker(Theme.surfaceContainer, 1.08)

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("usermenu.tabs.power")
                                color: popup.page === "power"
                                    ? Theme.onPrimary
                                    : Theme.onSurface

                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: popup.page = "power"
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: popup.page === "home"

                        Text {
                            text: I18n.t("usermenu.sections.settings")
                            color: Theme.outline
                            font.pixelSize: 10
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                        }

                        GridLayout {
                            columns: 2
                            Layout.fillWidth: true
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: root.settingsItems

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 66

                                    radius: 11
                                    color: tileMouse.containsMouse
                                        ? Qt.lighter(Theme.surfaceContainer, 1.12)
                                        : Qt.darker(Theme.surfaceContainer, 1.04)

                                    border.width: 1
                                    border.color: Qt.darker(Theme.outline, 1.25)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 9

                                        Text {
                                            Layout.preferredWidth: 25
                                            text: modelData.symbol
                                            color: Theme.primary
                                            font.pixelSize: 20
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("usermenu.settings." + modelData.id + ".title")
                                                color: Theme.onSurface
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("usermenu.settings." + modelData.id + ".subtitle")
                                                color: Theme.outline
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: tileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            UserController.openSettings(
                                                modelData.id
                                            )
                                            popup.visible = false
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        visible: popup.page === "power"

                        Text {
                            text: I18n.t("usermenu.sections.power")
                            color: Theme.outline
                            font.pixelSize: 10
                            font.bold: true
                            font.capitalization: Font.AllUppercase
                        }

                        GridLayout {
                            columns: 2
                            Layout.fillWidth: true
                            rowSpacing: 8
                            columnSpacing: 8

                            Repeater {
                                model: root.powerItems

                                delegate: Rectangle {
                                    required property var modelData

                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 66

                                    radius: 11
                                    color: powerTileMouse.containsMouse
                                        ? Qt.lighter(Theme.surfaceContainer, 1.12)
                                        : Qt.darker(Theme.surfaceContainer, 1.04)

                                    border.width: 1
                                    border.color: Qt.darker(Theme.outline, 1.25)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        spacing: 9

                                        Text {
                                            Layout.preferredWidth: 25
                                            text: modelData.symbol
                                            color: Theme.primary
                                            font.pixelSize: 19
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("usermenu.power." + modelData.id + ".title")
                                                color: Theme.onSurface
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: I18n.t("usermenu.power." + modelData.id + ".subtitle")
                                                color: Theme.outline
                                                font.pixelSize: 9
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }

                                    MouseArea {
                                        id: powerTileMouse
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            if (modelData.id === "lock") {
                                                UserController.executePower("lock")
                                                popup.visible = false
                                            } else {
                                                popup.pendingAction = modelData.id
                                                popup.page = "confirm"
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 12
                        visible: popup.page === "confirm"

                        Item {
                            Layout.fillHeight: true
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.actionTitle(popup.pendingAction)
                            color: Theme.onSurface
                            font.pixelSize: 18
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            Layout.fillWidth: true
                            text: root.actionDescription(popup.pendingAction)
                            color: Theme.outline
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Qt.darker(Theme.surfaceContainer, 1.05)

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.t("usermenu.confirm.cancel")
                                    color: Theme.onSurface
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        popup.pendingAction = ""
                                        popup.page = "power"
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 38
                                radius: 10
                                color: Theme.primary

                                Text {
                                    anchors.centerIn: parent
                                    text: I18n.t("usermenu.confirm.ok")
                                    color: Theme.onPrimary
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        UserController.executePower(
                                            popup.pendingAction
                                        )

                                        popup.visible = false
                                        popup.pendingAction = ""
                                    }
                                }
                            }
                        }

                        Item {
                            Layout.fillHeight: true
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        visible: popup.page !== "confirm"
                    }

                    Text {
                        visible: popup.page !== "confirm"
                        Layout.fillWidth: true

                        text: "Wayck " + I18n.t("usermenu.footer") + "  ·  Linux / Hyprland"
                        color: Theme.outline
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
