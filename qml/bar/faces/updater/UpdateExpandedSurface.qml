import QtQuick
import QtQuick.Layouts
import "../../../"

Item {
    id: root

    signal updateRequested()
    signal closeRequested()

    property real holdProgress: 0
    property bool holdActive: false
    property bool completed: false

    implicitWidth: 340
    implicitHeight: 204

    Rectangle {
        anchors.fill: parent
        radius: 17
        color: Qt.alpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.alpha(Theme.primary, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: "󰇚"
                    color: Theme.primary
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: "ATUALIZAÇÃO DISPONÍVEL"
                    color: Theme.onSurface
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    Layout.fillWidth: true
                    text: UpdateController.localVersion + "  →  " + UpdateController.remoteVersion
                    color: Theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Text {
                text: "×"
                color: Theme.outline
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: root.closeRequested()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: "Uma nova versão do Wayck está pronta. Segure o botão até o preenchimento concluir para instalar."
            color: Theme.onSurface
            opacity: 0.78
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            id: holdButton
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: Qt.darker(Theme.surfaceContainer, 1.28)
            border.width: 1
            border.color: root.holdActive ? Theme.primary : Theme.outline
            clip: true

            Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.holdProgress
                radius: parent.radius
                color: Theme.primary

                Behavior on width {
                    NumberAnimation {
                        duration: 90
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                visible: root.holdProgress > 0.015 && root.holdProgress < 1
                x: Math.max(0, parent.width * root.holdProgress - width / 2)
                anchors.verticalCenter: parent.verticalCenter
                width: 19
                height: 19
                radius: 10
                color: Qt.lighter(Theme.primary, 1.22)
                opacity: 0.9
            }

            Text {
                anchors.centerIn: parent
                text: root.completed
                    ? "Atualização iniciando…"
                    : (root.holdActive
                        ? "Continue segurando  " + Math.round(root.holdProgress * 100) + "%"
                        : "Segure para atualizar")
                color: root.holdProgress > 0.48 ? Theme.onPrimary : Theme.onSurface
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.completed

                onPressed: {
                    root.holdActive = true
                    holdAnimation.restart()
                }

                onReleased: {
                    root.holdActive = false
                    if (!root.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                onCanceled: {
                    root.holdActive = false
                    if (!root.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                cursorShape: Qt.PointingHandCursor
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.holdActive
                ? "Soltar antes do fim cancela a ação."
                : "A instalação atualizará os arquivos e reiniciará a shell."
            color: Theme.outline
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
        }
    }

    NumberAnimation {
        id: holdAnimation
        target: root
        property: "holdProgress"
        from: 0
        to: 1
        duration: 1850
        easing.type: Easing.Linear

        onFinished: {
            if (!root.holdActive || root.completed)
                return

            root.completed = true
            root.updateRequested()
        }
    }

    NumberAnimation {
        id: drainAnimation
        target: root
        property: "holdProgress"
        to: 0
        duration: Math.max(100, root.holdProgress * 210)
        easing.type: Easing.OutCubic
    }
}
