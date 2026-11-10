import QtQuick
import "../"

ShaderEffect {
    id: root

    property real radius: 0
    property real fillLevel: 0
    property real waveAmp: 0
    property vector2d itemSize: Qt.vector2d(width, height)
    property real phase: 0
    property real threeDimensional: 0.0

    property color color1: Theme.primary
    property color color2: Theme.primary

    fragmentShader: Qt.resolvedUrl("../assets/shaders/hold_wave.frag.qsb")
}