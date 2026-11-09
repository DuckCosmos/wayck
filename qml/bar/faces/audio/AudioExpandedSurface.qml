import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Pipewire
import "../../../"

Item {
    id: root

    signal closeRequested()

    property var trackedNodes: []

    readonly property var audioStreams: trackedNodes.filter(function(node) {
        if (!node || !node.isStream || !node.audio)
            return false

        const props = node.properties || ({})
        const mediaClass = props["media.class"] || ""
        return mediaClass === "" || mediaClass === "Stream/Output/Audio"
    })

    implicitWidth: 360
    implicitHeight: 280

    function refreshNodes(): void {
        trackedNodes = Pipewire.nodes.values
    }

    function appName(node): string {
        const props = node && node.properties ? node.properties : ({})
        return props["application.name"]
            || props["application.process.binary"]
            || node.description
            || node.name
            || "Aplicativo"
    }

    function streamDescription(node): string {
        const props = node && node.properties ? node.properties : ({})
        return props["media.name"]
            || props["media.title"]
            || props["window.title"]
            || node.name
            || "Saída de áudio"
    }

    PwObjectTracker {
        objects: root.trackedNodes
    }

    PwObjectTracker {
        objects: [Pipewire.defaultAudioSink]
    }

    Connections {
        target: Pipewire.nodes
        ignoreUnknownSignals: true
        function onValuesChanged() { root.refreshNodes() }
        function onObjectInsertedPost() { root.refreshNodes() }
        function onObjectRemovedPost() { root.refreshNodes() }
    }

    Component.onCompleted: refreshNodes()

    Rectangle {
        anchors.fill: parent
        radius: 16
        color: Qt.alpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 17
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 1

                Text {
                    text: "MIXER DE APLICATIVOS"
                    color: Theme.onSurface
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.8
                }

                Text {
                    text: root.audioStreams.length + " aplicativos emitindo áudio"
                    color: Theme.outline
                    font.pixelSize: 10
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

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.outline
            opacity: 0.22
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5

            RowLayout {
                Layout.fillWidth: true

                Text {
                    text: "Volume principal"
                    color: Theme.onSurface
                    font.pixelSize: 11
                    font.bold: true
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    text: Pipewire.defaultAudioSink?.audio
                        ? Math.round(Pipewire.defaultAudioSink.audio.volume * 100) + "%"
                        : "--%"
                    color: Theme.outline
                    font.pixelSize: 10
                }
            }

            Slider {
                id: masterVolumeSlider

                Layout.fillWidth: true
                from: 0
                to: 1.5

                enabled: !!Pipewire.defaultAudioSink?.audio

                value: Pipewire.defaultAudioSink?.audio
                    ? Pipewire.defaultAudioSink.audio.volume
                    : 0

                onMoved: {
                    const sink = Pipewire.defaultAudioSink

                    if (!sink?.audio)
                        return

                    sink.audio.volume = value

                    if (value > 0)
                        sink.audio.muted = false
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: streamList
                anchors.fill: parent
                clip: true
                spacing: 6
                model: root.audioStreams
                boundsBehavior: Flickable.StopAtBounds

                add: Transition {
                    ParallelAnimation {
                        NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Motion.contentFadeDuration }
                        NumberAnimation { property: "y"; from: 12; duration: Motion.menuContentDuration; easing.type: Motion.standard }
                    }
                }

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Motion.menuContentDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.layoutCurve
                    }
                }

                delegate: Item {
                    id: streamDelegate
                    required property var modelData
                    required property int index

                    property var node: modelData
                    readonly property var props: node && node.properties ? node.properties : ({})
                    readonly property bool muted: node && node.audio ? node.audio.muted : false
                    readonly property real volume: node && node.audio ? node.audio.volume : 0

                    width: streamList.width
                    height: 54

                    RowLayout {
                        anchors.fill: parent
                        spacing: 9

                        Rectangle {
                            Layout.preferredWidth: 34
                            Layout.preferredHeight: 34
                            radius: 10
                            color: Qt.alpha(Theme.primary, 0.14)

                            Text {
                                anchors.centerIn: parent
                                text: "♫"
                                color: Theme.primary
                                font.pixelSize: 17
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 5

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.appName(streamDelegate.node)
                                        color: Theme.onSurface
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.streamDescription(streamDelegate.node)
                                        color: Theme.outline
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }

                                Text {
                                    text: Math.round(streamDelegate.volume * 100) + "%"
                                    color: Theme.outline
                                    font.pixelSize: 10
                                }
                            }

                            Slider {
                                id: volumeSlider
                                Layout.fillWidth: true
                                Layout.preferredHeight: 15
                                from: 0
                                to: 1.5
                                value: streamDelegate.volume

                                onMoved: {
                                    if (!streamDelegate.node || !streamDelegate.node.audio)
                                        return
                                    streamDelegate.node.audio.volume = value
                                    if (value > 0)
                                        streamDelegate.node.audio.muted = false
                                }

                                background: Rectangle {
                                    x: volumeSlider.leftPadding
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: volumeSlider.availableWidth
                                    height: 4
                                    radius: 2
                                    color: Qt.darker(Theme.surfaceContainer, 1.5)

                                    Rectangle {
                                        width: parent.width * volumeSlider.visualPosition
                                        height: parent.height
                                        radius: parent.radius
                                        color: Theme.primary
                                    }
                                }

                                handle: Rectangle {
                                    x: volumeSlider.leftPadding
                                        + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                                    width: 11
                                    height: 11
                                    radius: 6
                                    color: Theme.primary
                                    border.width: 2
                                    border.color: Qt.lighter(Theme.primary, 1.2)
                                }
                            }
                        }

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 9
                            color: streamDelegate.muted
                                ? Qt.alpha(Theme.outline, 0.16)
                                : Qt.alpha(Theme.primary, 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: streamDelegate.muted ? "󰖁" : "󰕾"
                                color: streamDelegate.muted ? Theme.outline : Theme.primary
                                font.pixelSize: 15
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (streamDelegate.node && streamDelegate.node.audio)
                                        streamDelegate.node.audio.muted = !streamDelegate.node.audio.muted
                                }
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 5
                visible: root.audioStreams.length === 0

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "♪"
                    color: Theme.outline
                    font.pixelSize: 28
                }

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: Pipewire.ready ? "Nenhum aplicativo está emitindo áudio" : "Conectando ao PipeWire..."
                    color: Theme.outline
                    font.pixelSize: 10
                }
            }
        }
    }
}
