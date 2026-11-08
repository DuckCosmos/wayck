pragma Singleton
import QtQuick

QtObject {
    readonly property int fast: 120
    readonly property int normal: 180
    readonly property int medium: 250
    readonly property int slow: 320

    readonly property int hoverDuration: 190
    readonly property int surfaceOpenDuration: 420
    readonly property int surfaceCloseDuration: 300
    readonly property int surfaceRetargetDuration: 280
    readonly property int morphDuration: 420
    readonly property int layoutDuration: 320
    readonly property int stackDuration: 360
    readonly property int barResizeDuration: 260
    readonly property int colorDuration: 180
    readonly property int contentFadeDuration: 180
    readonly property int contentRevealDelay: 90
    readonly property int menuContentDuration: 220
    readonly property int wallpaperMoveDuration: 320

    readonly property int standard: Easing.OutCubic
    readonly property int standardIn: Easing.InCubic
    readonly property int standardInOut: Easing.InOutCubic

    readonly property list<real> standardCurve: [0.16, 1.0, 0.30, 1.0, 1, 1]
    readonly property list<real> surfaceOpenCurve: [0.16, 1.0, 0.25, 1.0, 1, 1]
    readonly property list<real> surfaceCloseCurve: [0.40, 0.0, 0.20, 1.0, 1, 1]
    readonly property list<real> morphCurve: [0.20, 0.90, 0.20, 1.0, 1, 1]
    readonly property list<real> layoutCurve: [0.16, 1.0, 0.30, 1.0, 1, 1]
    readonly property list<real> contentCurve: [0.20, 0.80, 0.20, 1.0, 1, 1]
    readonly property list<real> selectionCurve: [0.22, 1.0, 0.36, 1.0, 1, 1]
    readonly property list<real> hoverEnterCurve: [0.20, 0.90, 0.25, 1.0, 1, 1]
    readonly property list<real> hoverExitCurve: [0.40, 0.0, 0.20, 1.0, 1, 1]

    readonly property real subtleScale: 0.98
    readonly property real entranceScale: 0.94
    readonly property real exitScale: 0.97
}
