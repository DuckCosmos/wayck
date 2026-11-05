import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import "../../../services"
import "."

BarCard {
    id: root

    property var player: MediaService.activePlayer

    implicitHeight: 36
    horizontalPadding: 8

    Item {
        Layout.preferredWidth: 26
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: root.cPrimary
            clip: true

            Image {
                id: albumArt
                anchors.fill: parent
                source: root.player ? root.player.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
            }

            OpacityMask {
                anchors.fill: albumArt

                source: albumArt

                maskSource: Rectangle {
                    width: 26
                    height: 26
                    radius: 5
                    color: "white"
                }

                visible: root.player !== null
                    && root.player.trackArtUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "♫"
                color: root.cOnPrimary
                font.pixelSize: 17
                visible: root.player === null || root.player.trackArtUrl === ""
            }
        }
    }

    ColumnLayout {
        spacing: 0
        Layout.preferredWidth: 112
        Layout.minimumWidth: 80

        Text {
            Layout.fillWidth: true
            text: root.player
                ? (root.player.trackTitle || root.player.identity || "Player")
                : "Sem player"
            color: root.cOnSurface
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.player
                ? (root.player.trackArtist || "Artista desconhecido")
                : "Aguardando MPRIS"
            color: root.cOutline
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Item {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 24

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: "‹"
            color: root.player && root.player.canGoPrevious
                ? root.cOnSurface : root.cOutline
            font.pixelSize: 23
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canGoPrevious
            onClicked: root.player.previous()
        }
    }

    Item {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 24

        Text {
            anchors.centerIn: parent
            text: root.player && root.player.isPlaying ? "Ⅱ" : "▶"
            color: root.player && root.player.canTogglePlaying
                ? root.cPrimary : root.cOutline
            font.pixelSize: 14
            font.bold: true
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canTogglePlaying
            onClicked: root.player.togglePlaying()
        }
    }

    Item {
        Layout.preferredWidth: 18
        Layout.preferredHeight: 24

        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -2
            text: "›"
            color: root.player && root.player.canGoNext
                ? root.cOnSurface : root.cOutline
            font.pixelSize: 23
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }
    }
}
