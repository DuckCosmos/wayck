import QtQuick
import QtQuick.Layouts
import "../../../"

Item {
    id: root

    property var player: MprisController.activePlayer

    signal closeRequested()

    RowLayout {
        anchors.fill: parent
        anchors.margins: 24
        spacing: 22

        Rectangle {
            Layout.preferredWidth: 172
            Layout.preferredHeight: 172
            radius: 14
            color: Theme.surface
            clip: true

            Image {
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: root.player !== null && root.player.trackArtUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "♫"
                color: Theme.primary
                font.pixelSize: 54
                visible: !root.player || !root.player.trackArtUrl
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.player ? (root.player.identity || "Now playing") : "No player"
                    color: Theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: "×"
                    color: Theme.onSurface
                    font.pixelSize: 22

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8
                        onClicked: root.closeRequested()
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.player
                    ? (root.player.trackTitle || I18n.t("player.title"))
                    : I18n.t("player.none")
                color: Theme.onSurface
                font.pixelSize: 19
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true
                text: root.player
                    ? (root.player.trackArtist || I18n.t("player.unknownArtist"))
                    : I18n.t("player.waiting")
                color: Theme.outline
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Item { Layout.fillHeight: true }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 26

                Text {
                    text: "‹"
                    color: root.player && root.player.canGoPrevious ? Theme.onSurface : Theme.outline
                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        enabled: root.player !== null && root.player.canGoPrevious
                        onClicked: root.player.previous()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46
                    radius: 23
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent
                        text: root.player && root.player.isPlaying ? "Ⅱ" : "▶"
                        color: Theme.onPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: root.player !== null && root.player.canTogglePlaying
                        onClicked: root.player.togglePlaying()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }

                Text {
                    text: "›"
                    color: root.player && root.player.canGoNext ? Theme.onSurface : Theme.outline
                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10
                        enabled: root.player !== null && root.player.canGoNext
                        onClicked: root.player.next()
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    }
                }
            }
        }
    }
}
