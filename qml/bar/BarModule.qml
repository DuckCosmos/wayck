import QtQuick
import "../"

Item {
    id: root

    required property string moduleId

    property string sectionName: ""
    property int order: 0
    property real compactness: 0
    property bool shown: true

    readonly property int priority: BarModuleRegistry.priority(moduleId)

    signal surfaceRequested(var sourceItem, string surfaceId, var surfaceData)

    // Keep natural metrics available to Bar.evaluate(); animate only the slot.
    visible: shown || opacity > 0.01
    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0
    width: shown ? implicitWidth : 0
    height: implicitHeight
    opacity: shown ? 1 : 0
    scale: shown ? 1 : Motion.subtleScale

    Behavior on width {
        NumberAnimation {
            duration: Motion.barResizeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.layoutCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.contentFadeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.contentCurve
        }
    }
    Behavior on scale {
        NumberAnimation {
            duration: Motion.barResizeDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    Connections {
        target: loader.item
        ignoreUnknownSignals: true

        function onExpandRequested(sourceItem, surfaceData) {
            if (sourceItem)
                root.surfaceRequested(sourceItem, root.moduleId, surfaceData)
        }
    }

    Loader {
        id: loader

        source: BarModuleRegistry.faceFile(root.moduleId)

        onLoaded: {
            if (item && "compactness" in item)
                item.compactness = Qt.binding(() => root.compactness)

            if (root.debug)
                console.log("[WAYCK INPUT] face loaded:", root.moduleId,
                    "expandRequested=", !!item && ("expandRequested" in item),
                    "size=", item ? item.implicitWidth + "x" + item.implicitHeight : "null")
        }

        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("[WAYCK] módulo falhou ao carregar:", root.moduleId, source)
        }
    }
}
