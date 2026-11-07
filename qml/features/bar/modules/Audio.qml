import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire
import "../../../core"

RowLayout {
    id: root

    property var sink: Pipewire.defaultAudioSink
    property var source: Pipewire.defaultAudioSource

    spacing: 6

    PwObjectTracker {
        objects: [
            root.sink,
            root.source
        ]
    }

    function isReady(node) {
        return node !== null
            && node !== undefined
            && node.ready
            && node.audio !== null
    }

    function toggleMute(node) {
        if (!isReady(node))
            return

        node.audio.muted = !node.audio.muted
    }

    function adjustVolume(node, delta) {
        if (!isReady(node))
            return

        node.audio.volume = Math.max(
            0,
            Math.min(1, node.audio.volume + delta)
        )
    }

    function percentage(node) {
        if (!isReady(node) || node.audio.muted)
            return "0%"

        return Math.round(node.audio.volume * 100) + "%"
    }

    // VOLUME
    BarCard {

        implicitHeight: 36

        Item {
            Layout.preferredWidth: 51
            Layout.preferredHeight: 24

            RowLayout {
                anchors.fill: parent
                spacing: 4

                Text {
                    text: !root.isReady(root.sink)
                        ? "󰖁"
                        : root.sink.audio.muted
                            ? "󰖁"
                            : "󰕾"

                    color: root.isReady(root.sink)
                        && !root.sink.audio.muted
                        ? Theme.primary
                        : Theme.outline

                    font.pixelSize: 16
                }

                Text {
                    text: root.percentage(root.sink)
                    color: Theme.onSurface
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                onClicked: root.toggleMute(root.sink)

                onWheel: function(wheel) {
                    const direction = wheel.angleDelta.y > 0 ? 1 : -1
                    const steps = Math.max(
                        1,
                        Math.round(Math.abs(wheel.angleDelta.y) / 120)
                    )

                    root.adjustVolume(
                        root.sink,
                        direction * 0.05 * steps
                    )

                    wheel.accepted = true
                }
            }
        }
    }

    // MICROFONE
    BarCard {

        implicitHeight: 36

        Item {
            Layout.preferredWidth: 51
            Layout.preferredHeight: 24

            RowLayout {
                anchors.fill: parent
                spacing: 4

                Text {
                    text: !root.isReady(root.source)
                        ? "󰍭"
                        : root.source.audio.muted
                            ? "󰍭"
                            : "󰍬"

                    color: root.isReady(root.source)
                        && !root.source.audio.muted
                        ? Theme.primary
                        : Theme.outline

                    font.pixelSize: 16
                }

                Text {
                    text: root.percentage(root.source)
                    color: Theme.onSurface
                    font.pixelSize: 11
                    font.bold: true
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                onClicked: root.toggleMute(root.source)

                onWheel: function(wheel) {
                    const direction = wheel.angleDelta.y > 0 ? 1 : -1
                    const steps = Math.max(
                        1,
                        Math.round(Math.abs(wheel.angleDelta.y) / 120)
                    )

                    root.adjustVolume(
                        root.source,
                        direction * 0.05 * steps
                    )

                    wheel.accepted = true
                }
            }
        }
    }
}