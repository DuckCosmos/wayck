import QtQuick
import QtQuick.Layouts
import "../../../"

MorphSurface {
    id: expandedRoot

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

                source: expandedRoot.player
                    ? expandedRoot.player.trackArtUrl
                    : ""

                fillMode: Image.PreserveAspectCrop
                asynchronous: true

                visible: expandedRoot.player !== null
                    && expandedRoot.player.trackArtUrl !== ""
            }

            Text {
                anchors.centerIn: parent
                text: "♫"
                color: Theme.primary
                font.pixelSize: 54

                visible: !expandedRoot.player
                    || !expandedRoot.player.trackArtUrl
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

                    text: expandedRoot.player
                        ? (expandedRoot.player.identity
                            || I18n.t("player.title"))
                        : I18n.t("player.none")

                    color: Theme.outline
                    font.pixelSize: 11
                    elide: Text.ElideRight
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter

                    text: "×"
                    color: Theme.surfaceForeground
                    font.pixelSize: 22

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -8

                        onClicked: expandedRoot.closeRequested()

                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }

            Text {
                Layout.fillWidth: true

                text: expandedRoot.player
                    ? (expandedRoot.player.trackTitle
                        || I18n.t("player.title"))
                    : I18n.t("player.none")

                color: Theme.surfaceForeground
                font.pixelSize: 19
                font.bold: true
                elide: Text.ElideRight
                maximumLineCount: 2
                wrapMode: Text.Wrap
            }

            Text {
                Layout.fillWidth: true

                text: expandedRoot.player
                    ? (expandedRoot.player.trackArtist
                        || I18n.t("player.unknownArtist"))
                    : I18n.t("player.waiting")

                color: Theme.outline
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Item {
                Layout.fillHeight: true
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 26

                Text {
                    text: "‹"

                    color: expandedRoot.player
                        && expandedRoot.player.canGoPrevious
                        ? Theme.surfaceForeground
                        : Theme.outline

                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10

                        enabled: expandedRoot.player !== null
                            && expandedRoot.player.canGoPrevious

                        onClicked: expandedRoot.player.previous()

                        cursorShape: enabled
                            ? Qt.PointingHandCursor
                            : Qt.ArrowCursor
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46

                    radius: 23
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent

                        text: expandedRoot.player
                            && expandedRoot.player.isPlaying
                            ? "Ⅱ"
                            : "▶"

                        color: Theme.onPrimary
                        font.pixelSize: 18
                        font.bold: true
                    }

                    MouseArea {
                        anchors.fill: parent

                        enabled: expandedRoot.player !== null
                            && expandedRoot.player.canTogglePlaying

                        onClicked: expandedRoot.player.togglePlaying()

                        cursorShape: Qt.PointingHandCursor
                    }
                }

                Text {
                    text: "›"

                    color: expandedRoot.player
                        && expandedRoot.player.canGoNext
                        ? Theme.surfaceForeground
                        : Theme.outline

                    font.pixelSize: 34

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10

                        enabled: expandedRoot.player !== null
                            && expandedRoot.player.canGoNext

                        onClicked: expandedRoot.player.next()

                        cursorShape: enabled
                            ? Qt.PointingHandCursor
                            : Qt.ArrowCursor
                    }
                }
            }
        }
    }

    onCloseRequested: morph.close()
}
