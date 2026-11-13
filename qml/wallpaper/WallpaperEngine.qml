
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

Variants {
    model: Quickshell.screens

    delegate: PanelWindow {
        id: wallpaperWindow

        required property var modelData
        screen: modelData

        readonly property string stateHome:
            Quickshell.env("XDG_STATE_HOME") ||
            (Quickshell.env("HOME") + "/.local/state")

        readonly property string wallpaperStateFile:
            stateHome + "/wayck/wallpaper"

        readonly property url transitionShader:
            Qt.resolvedUrl("../assets/shaders/wallpaper_transition.frag.qsb")

        property string wallpaperPath: ""
        property string pathA: ""
        property string pathB: ""

        property int activeLayer: 0
        property int activeTransitionType: 0

        property real transitionProgress: 1.0

        property real transitionOriginX: 0.5
        property real transitionOriginY: 0.5

        property bool wipeIsVertical: false
        property int swipeDirection: 0

        property bool hasWallpaper: false
        property bool isPreloading: false

        property string transitionPath: ""
        property string queuedPath: ""

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        visible: true
        focusable: false
        aboveWindows: false
        exclusiveZone: -1
        color: "#000000"

        WlrLayershell.namespace: "wayck-wallpaper"
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.exclusiveZone: -1
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        FileView {
            path: wallpaperWindow.wallpaperStateFile
            watchChanges: true

            onFileChanged: reload()

            onLoaded: {
                const path = text().trim()

                if (path.length > 0)
                    wallpaperWindow.setWallpaper(path)
            }

            onLoadFailed: error => {
                console.warn(
                    "[WallpaperEngine] Erro ao ler wallpaper:",
                    error
                )
            }
        }

        ShaderEffect {
            id: shaderA

            anchors.fill: parent
            visible: false
            layer.enabled: layerA.layer.enabled

            property vector2d itemSize:
                Qt.vector2d(width, height)

            property real progress:
                wallpaperWindow.transitionProgress

            property real transitionType:
                wallpaperWindow.activeTransitionType

            property vector2d origin:
                Qt.vector2d(
                    wallpaperWindow.transitionOriginX,
                    wallpaperWindow.transitionOriginY
                )

            property vector4d params:
                Qt.vector4d(
                    wallpaperWindow.wipeIsVertical ? 1.0 : 0.0,
                    wallpaperWindow.swipeDirection,
                    0.0,
                    0.0
                )

            fragmentShader: wallpaperWindow.transitionShader
        }

        ShaderEffect {
            id: shaderB

            anchors.fill: parent
            visible: false
            layer.enabled: layerB.layer.enabled

            property vector2d itemSize:
                Qt.vector2d(width, height)

            property real progress:
                wallpaperWindow.transitionProgress

            property real transitionType:
                wallpaperWindow.activeTransitionType

            property vector2d origin:
                Qt.vector2d(
                    wallpaperWindow.transitionOriginX,
                    wallpaperWindow.transitionOriginY
                )

            property vector4d params:
                Qt.vector4d(
                    wallpaperWindow.wipeIsVertical ? 1.0 : 0.0,
                    wallpaperWindow.swipeDirection,
                    0.0,
                    0.0
                )

            fragmentShader: wallpaperWindow.transitionShader
        }

        Item {
            id: layerA

            anchors.fill: parent

            readonly property bool isIncoming:
                wallpaperWindow.activeLayer === 0

            z: isIncoming ? 2 : 1

            visible: isIncoming ||
                wallpaperWindow.transitionProgress < 1.0

            opacity: {
                if (wallpaperWindow.isPreloading && isIncoming)
                    return 0

                if (wallpaperWindow.activeTransitionType !== 0)
                    return 1

                return isIncoming
                    ? wallpaperWindow.transitionProgress
                    : 1 - wallpaperWindow.transitionProgress
            }

            layer.enabled:
                isIncoming &&
                !wallpaperWindow.isPreloading &&
                wallpaperWindow.activeTransitionType !== 0 &&
                wallpaperWindow.transitionProgress < 1

            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shaderA
                maskThresholdMin: 0
                maskSpreadAtMin: 0
            }

            Image {
                id: imageA

                anchors.fill: parent

                source: wallpaperWindow.pathA.length > 0
                    ? "file://" + wallpaperWindow.pathA
                    : ""

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true

                onStatusChanged: {
                    if (status === Image.Ready)
                        wallpaperWindow.tryStartTransition()

                    if (status === Image.Error)
                        console.warn(
                            "[WallpaperEngine] Erro na imagem A:",
                            source
                        )
                }
            }
        }

        Item {
            id: layerB

            anchors.fill: parent

            readonly property bool isIncoming:
                wallpaperWindow.activeLayer === 1

            z: isIncoming ? 2 : 1

            visible: isIncoming ||
                wallpaperWindow.transitionProgress < 1.0

            opacity: {
                if (wallpaperWindow.isPreloading && isIncoming)
                    return 0

                if (wallpaperWindow.activeTransitionType !== 0)
                    return 1

                return isIncoming
                    ? wallpaperWindow.transitionProgress
                    : 1 - wallpaperWindow.transitionProgress
            }

            layer.enabled:
                isIncoming &&
                !wallpaperWindow.isPreloading &&
                wallpaperWindow.activeTransitionType !== 0 &&
                wallpaperWindow.transitionProgress < 1

            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: shaderB
                maskThresholdMin: 0
                maskSpreadAtMin: 0
            }

            Image {
                id: imageB

                anchors.fill: parent

                source: wallpaperWindow.pathB.length > 0
                    ? "file://" + wallpaperWindow.pathB
                    : ""

                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                smooth: true

                onStatusChanged: {
                    if (status === Image.Ready)
                        wallpaperWindow.tryStartTransition()

                    if (status === Image.Error)
                        console.warn(
                            "[WallpaperEngine] Erro na imagem B:",
                            source
                        )
                }
            }
        }

        function setWallpaper(path) {
            if (!path || path.length === 0)
                return

            if (path === wallpaperPath && !isPreloading)
                return

            if (isPreloading) {
                if (path !== transitionPath)
                    queuedPath = path

                return
            }

            if (path === transitionPath)
                return

            if (!hasWallpaper) {
                pathA = path
                wallpaperPath = path
                activeLayer = 0
                hasWallpaper = true
                transitionProgress = 1
                return
            }

            prepareTransition(path)
        }

        function prepareTransition(path) {
            transitionPath = path

            activeTransitionType = Math.floor(Math.random() * 5)

            wipeIsVertical = Math.random() < 0.5

            swipeDirection = Math.floor(Math.random() * 8)

            transitionOriginX = 0.15 + Math.random() * 0.7
            transitionOriginY = 0.15 + Math.random() * 0.7

            isPreloading = true
            transitionProgress = 0

            activeLayer = activeLayer === 0 ? 1 : 0

            if (activeLayer === 0)
                pathA = path
            else
                pathB = path

            tryStartTransition()
        }

        function tryStartTransition() {
            if (!isPreloading)
                return

            const incomingImage = activeLayer === 0
                ? imageA
                : imageB

            if (incomingImage.status !== Image.Ready)
                return

            isPreloading = false
            transitionProgress = 0

            transitionAnimation.restart()
        }

        function finishTransition() {
            wallpaperPath = transitionPath
            transitionPath = ""

            transitionProgress = 1

            if (activeLayer === 0)
                pathB = ""
            else
                pathA = ""

            if (queuedPath.length > 0) {
                const nextPath = queuedPath
                queuedPath = ""

                if (nextPath !== wallpaperPath)
                    prepareTransition(nextPath)
            }
        }

        NumberAnimation {
            id: transitionAnimation

            target: wallpaperWindow
            property: "transitionProgress"

            from: 0
            to: 1

            duration: 900
            easing.type: Easing.InOutCubic

            onFinished: wallpaperWindow.finishTransition()
        }
    }
}
