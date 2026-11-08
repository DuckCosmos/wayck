import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import "../../../"

BarCard {
    id: root

    property var player: MprisController.activePlayer

    implicitHeight: 36
    horizontalPadding: 8

    function openExpanded(): void {
        expandDelay.stop()
        MorphController.open(albumArea, "player", null, QsWindow.window)
    }

    Item {
        id: albumArea

        Layout.preferredWidth: 26
        Layout.preferredHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: Theme.primary
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
                color: Theme.onPrimary
                font.pixelSize: 17
                visible: root.player === null || root.player.trackArtUrl === ""
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onEntered: expandDelay.restart()
            onExited: expandDelay.stop()
            onClicked: root.openExpanded()
        }

        Timer {
            id: expandDelay

            interval: 220
            repeat: false

            onTriggered: root.openExpanded()
        }
    }

    ColumnLayout {
        spacing: 0
        Layout.preferredWidth: 50
        Layout.minimumWidth: 50

        Text {
            Layout.fillWidth: true
            text: root.player
                ? (root.player.trackTitle || root.player.identity || I18n.t("player.title"))
                : I18n.t("player.none")
            color: Theme.onSurface
            font.pixelSize: 11
            font.bold: true
            elide: Text.ElideRight
        }

        Text {
            Layout.fillWidth: true
            text: root.player
                ? (root.player.trackArtist || I18n.t("player.unknownArtist"))
                : I18n.t("player.waiting")
            color: Theme.outline
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
                ? Theme.onSurface : Theme.outline
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
                ? Theme.primary : Theme.outline
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
                ? Theme.onSurface : Theme.outline
            font.pixelSize: 23
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }
    }
}
