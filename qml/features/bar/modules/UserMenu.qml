import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../services" as Services
import "../../../core"

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 7

    readonly property var settingsItems: [
        { id: "hyprland", title: "Hyprland", subtitle: "Configuração", symbol: "H" },
        { id: "displays", title: "Monitores", subtitle: "Resolução e telas", symbol: "▣" },
        { id: "network", title: "Rede", subtitle: "Conexões", symbol: "⌁" },
        { id: "audio", title: "Áudio", subtitle: "Saída e microfone", symbol: "♫" },
        { id: "bluetooth", title: "Bluetooth", subtitle: "Dispositivos", symbol: "ᛒ" },
        { id: "appearance", title: "Aparência", subtitle: "Tema e fontes", symbol: "◈" },
        { id: "system", title: "Sistema", subtitle: "Configurações gerais", symbol: "⚙" },
        { id: "monitor", title: "Monitor do sistema", subtitle: "Processos e recursos", symbol: "▥" }
    ]

    readonly property var powerItems: [
        { id: "lock", title: "Bloquear", subtitle: "Bloquear a sessão", symbol: "▣" },
        { id: "suspend", title: "Suspender", subtitle: "Colocar em repouso", symbol: "☾" },
        { id: "reboot", title: "Reiniciar", subtitle: "Reiniciar o computador", symbol: "↻" },
        { id: "poweroff", title: "Desligar", subtitle: "Desligar o computador", symbol: "⏻" },
        { id: "logout", title: "Sair da sessão", subtitle: "Encerrar o Hyprland", symbol: "⇥" }
    ]

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
        switch (action) {
        case "suspend": return "Suspender o computador?"
        case "reboot": return "Reiniciar o computador?"
        case "poweroff": return "Desligar o computador?"
        case "logout": return "Encerrar a sessão?"
        default: return "Confirmar ação?"
        }
    }

    function actionDescription(action) {
        switch (action) {
        case "suspend": return "O computador entrará em modo de suspensão."
        case "reboot": return "Todos os aplicativos serão encerrados."
        case "poweroff": return "O computador será desligado."
        case "logout": return "Você será desconectado do Hyprland."
        default: return ""
        }
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
                text: Services.UserService.username
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
                                text: Services.UserService.username.length > 0
                                    ? Services.UserService.username
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
                                text: Services.UserService.username
                                color: Theme.onSurface
                                font.pixelSize: 16
                                font.bold: true
                            }

                            Text {
                                text: Services.UserService.hostname
                                    + "  ·  " + Services.UserService.desktop

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
                                text: "Controle"
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
                                text: "Energia"
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
                            text: "CONFIGURAÇÕES"
                            color: Theme.outline
                            font.pixelSize: 10
                            font.bold: true
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
                                                text: modelData.title
                                                color: Theme.onSurface
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.subtitle
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
                                            Services.UserService.openSettings(
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
                            text: "ENERGIA E SESSÃO"
                            color: Theme.outline
                            font.pixelSize: 10
                            font.bold: true
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
                                                text: modelData.title
                                                color: Theme.onSurface
                                                font.pixelSize: 11
                                                font.bold: true
                                                elide: Text.ElideRight
                                            }

                                            Text {
                                                Layout.fillWidth: true
                                                text: modelData.subtitle
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
                                                Services.UserService.executePower("lock")
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
                                    text: "Cancelar"
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
                                    text: "Confirmar"
                                    color: Theme.onPrimary
                                    font.pixelSize: 12
                                    font.bold: true
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        Services.UserService.executePower(
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

                        text: "Wayck Control Center  ·  Linux / Hyprland"
                        color: Theme.outline
                        font.pixelSize: 9
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }
}
