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

    visible: shown

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    width: implicitWidth
    height: implicitHeight

    Loader {
        id: loader

        source: BarModuleRegistry.faceFile(root.moduleId)

        onLoaded: {
            if (item && "compactness" in item)
                item.compactness = Qt.binding(() => root.compactness)
        }

        onStatusChanged: {
            if (status === Loader.Error)
                console.warn("[WAYCK] módulo falhou ao carregar:", root.moduleId, source)
        }
    }
}
