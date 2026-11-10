import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt5Compat.GraphicalEffects
import "../../../"

BarCard {
    id: root

    // Keep morph capture geometry aligned with the unscaled source anchor.
    hoverScale: 1

    property var player: MprisController.activePlayer
    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    signal expandRequested(var sourceItem, var surfaceData, var windowRef)

    implicitHeight: 36
    horizontalPadding: 8

    function requestExpand(reason): void {
        expandDelay.stop()
        if (debug)
            console.log("[WAYCK INPUT] player emit expandRequested:",
                reason, "anchor=", root.width + "x" + root.height,
                "window=", !!QsWindow.window)
        expandRequested(root, null, QsWindow.window)
    }

    HoverHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onHoveredChanged: {
            MorphController.setSourceHovered(root, hovered)

            if (root.debug)
                console.log("[WAYCK INPUT] player card hover:", hovered)

            if (hovered)
                expandDelay.restart()
            else
                expandDelay.stop()
        }
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
            hoverEnabled: false
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.PointingHandCursor

            onClicked: {
                if (root.debug)
                    console.log("[WAYCK INPUT] player MouseArea clicked")
                root.requestExpand("click")
            }
        }

        Timer {
            id: expandDelay

            interval: Motion.hoverDwellDuration
            repeat: false

            onTriggered: root.requestExpand("hover dwell")
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
            color: Theme.surfaceForeground
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
                ? Theme.surfaceForeground : Theme.outline
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
                ? Theme.surfaceForeground : Theme.outline
            font.pixelSize: 23
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.player !== null && root.player.canGoNext
            onClicked: root.player.next()
        }
    }
}
