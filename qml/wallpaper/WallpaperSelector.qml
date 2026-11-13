
import Quickshell
import Quickshell.Wayland
import QtQuick.Layouts
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../"

PanelWindow {
    id: root
    required property string wallpaperExecutable

    signal dismissed()

    property bool show: false
    property bool closing: false

    property var wallpapers: []
    property var filteredWallpapers: wallpapers

    property string selectedWallpaper:
        wallpaperView.currentIndex >= 0 &&
        wallpaperView.currentIndex < filteredWallpapers.length
        ? filteredWallpapers[wallpaperView.currentIndex]
        : ""

    anchors {
        bottom: true
    }

    margins {
        bottom: 40
    }

    WlrLayershell.layer: WlrLayer.Overlay
    exclusiveZone: -1

    WlrLayershell.keyboardFocus:
        closing ? WlrKeyboardFocus.None :
        show ? WlrKeyboardFocus.Exclusive :
        WlrKeyboardFocus.None

    implicitHeight: 280
    implicitWidth: 800
    color: "transparent"

    Timer {
        id: closeTimer

        interval: Motion.surfaceCloseDuration + 40
        repeat: false

        onTriggered: {
            root.closing = false
            root.dismissed()
        }
    }

    function open() {
        if (show || closing)
            return

        closing = false
        show = true

        Qt.callLater(() => {
            searchWallpaper.forceActiveFocus()
        })
    }

    function close() {
        if (!show || closing)
            return

        closing = true
        show = false
        closeTimer.start()
    }

    function filterWallpapers(query) {
        const search = query.toLowerCase().trim()

        filteredWallpapers = !search
            ? wallpapers
            : wallpapers.filter(path => {
                const filename = path.split("/").pop().toLowerCase()
                return filename.includes(search)
            })

        wallpaperView.currentIndex =
            filteredWallpapers.length > 0 ? 0 : -1

        if (filteredWallpapers.length > 0) {
            Qt.callLater(() => {
                wallpaperView.positionViewAtIndex(
                    0,
                    ListView.Center
                )
            })
        }
    }

    Process {
        id: wallpaperList

        command: [root.wallpaperExecutable, "list"]

        stdout: StdioCollector {
            id: output
        }

        stderr: StdioCollector {
            id: errors
        }

        onExited: exitCode => {
            console.log("EXIT:", exitCode)
            console.log("STDOUT:", JSON.stringify(output.text))
            console.log("STDERR:", errors.text)

            if (exitCode !== 0)
                return

            const result = output.text.trim()

            root.wallpapers = result.length > 0
                ? result.split("\n").filter(path => path.trim().length > 0)
                : []

            root.filteredWallpapers = root.wallpapers

            wallpaperView.currentIndex =
                root.wallpapers.length > 0 ? 0 : -1

            console.log("WALLPAPERS:", root.wallpapers.length)

            wallpaperIndex.running = true
        }
    }

    Process {
        id: wallpaperIndex

        command: [root.wallpaperExecutable, "current"]

        stdout: StdioCollector {
            onStreamFinished: {
                const currentWallpaper = text.trim()

                const index = root.wallpapers.indexOf(currentWallpaper)

                if (index >= 0) {
                    const filteredIndex =
                        root.filteredWallpapers.indexOf(currentWallpaper)

                    if (filteredIndex >= 0) {
                        wallpaperView.currentIndex = filteredIndex

                        Qt.callLater(() => {
                            wallpaperView.positionViewAtIndex(
                                filteredIndex,
                                ListView.Center
                            )
                        })
                    }
                }
            }
        }
    }

    Process {
        id: setWallpaper

        command: [root.wallpaperExecutable, "set", root.selectedWallpaper]
    }

    Rectangle {
        id: wallpaperCard

        opacity: show ? 1 : 0

        anchors.fill: parent

        color: Theme.surfaceContainer
        border.color: Theme.primary
        border.width: 1
        radius: 10

        transform: Translate {
            y: root.show ? 0 : 100

            Behavior on y {
                SpringAnimation {
                    spring: 3
                    damping: 0.2
                    mass: 1
                    epsilon: 0.01
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            ListView {
                id: wallpaperView

                Layout.fillWidth: true
                Layout.fillHeight: true

                model: root.filteredWallpapers

                orientation: ListView.Horizontal
                spacing: 15
                clip: true

                cacheBuffer: width * 3
                reuseItems: true

                currentIndex: -1

                snapMode: ListView.SnapOneItem

                boundsBehavior: Flickable.StopAtBounds

                header: Item {
                    width: (wallpaperView.width - 110) / 2
                    height: wallpaperView.height
                }

                footer: Item {
                    width: (wallpaperView.width - 110) / 2
                    height: wallpaperView.height
                }

                NumberAnimation {
                    id: scrollAnimation

                    target: wallpaperView
                    property: "contentX"

                    duration: 350
                    easing.type: Easing.OutCubic
                }

                delegate: Item {
                    width: 190
                    height: 160

                    property bool selected: ListView.isCurrentItem

                    z: selected ? 1 : 0

                    Rectangle {
                        id: wallpaperContainer

                        width: parent.selected ? 190 : 170
                        height: parent.selected ? 160 : 145

                        anchors.centerIn: parent

                        radius: 8
                        color: Theme.primary
                        clip: true

                        Behavior on width {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: 350
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            id: wallpaperImage

                            anchors.fill: parent

                            source: "file://" + modelData

                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true

                            sourceSize: Qt.size(280, 220)

                            visible: false
                        }

                        OpacityMask {
                            anchors.fill: parent

                            source: wallpaperImage

                            maskSource: Rectangle {
                                width: wallpaperContainer.width
                                height: wallpaperContainer.height

                                radius: 8
                                color: "white"
                            }

                            opacity: parent.parent.selected ? 1 : 0.55

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 400
                                }
                            }
                        }
                    }
                }

                onCountChanged: {
                    if (count === 0) {
                        currentIndex = -1
                    } else if (currentIndex < 0 || currentIndex >= count) {
                        currentIndex = 0

                        positionViewAtIndex(
                            0,
                            ListView.Center
                        )
                    }
                }

                onCurrentIndexChanged: {
                    Qt.callLater(() => {
                        if (!currentItem)
                            return

                        scrollAnimation.to =
                            currentItem.x - (width - currentItem.width) / 2

                        scrollAnimation.restart()
                    })
                }
            }

            Rectangle {
                Layout.preferredHeight: 32
                Layout.fillWidth: true

                color: "transparent"
                border.color: Theme.primary
                border.width: 1
                radius: 12

                TextInput {
                    id: searchWallpaper

                    anchors.fill: parent
                    anchors.margins: 8

                    color: Theme.surfaceForeground

                    verticalAlignment: TextInput.AlignVCenter

                    font.family: Qt.application.font.family
                    font.pixelSize: 16

                    Keys.onPressed: event => {
                        if (!event.isAutoRepeat)
                            SoundController.play("click")

                        if (event.key === Qt.Key_Escape) {
                            root.close()
                            event.accepted = true

                        } else if (event.key === Qt.Key_Right) {
                            if (wallpaperView.currentIndex < wallpaperView.count - 1) {
                                wallpaperView.currentIndex++
                            }

                            event.accepted = true

                        } else if (event.key === Qt.Key_Left) {
                            if (wallpaperView.currentIndex > 0) {
                                wallpaperView.currentIndex--
                            }

                            event.accepted = true

                        } else if (
                            event.key === Qt.Key_Enter ||
                            event.key === Qt.Key_Return
                        ) {
                            SoundController.play("clickbutton")
                            setWallpaper.running = true

                            event.accepted = true
                        }
                    }

                    onTextChanged: {
                        root.filterWallpapers(text)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        wallpaperList.running = true

        Qt.callLater(() => {
            root.open()
        })
    }
}
