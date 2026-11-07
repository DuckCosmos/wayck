import QtQuick
import ".."

// "Caixa" de um módulo da barra: carrega o arquivo certo (via BarRegistry),
// entrega o nível de compactação e expõe o tamanho pro layout.
// (As cores não passam mais por aqui: cada módulo lê o Theme direto.)
Item {
    id: root

    required property string moduleId

    property string sectionName: ""
    property int order: 0              // posição global (esq → centro → dir)
    property real compactness: 0       // 0 = normal, 1 = compacto
    property bool shown: true          // false = escondido por falta de espaço

    readonly property int priority: BarRegistry.priority(moduleId)

    visible: shown

    implicitWidth: loader.item ? loader.item.implicitWidth : 0
    implicitHeight: loader.item ? loader.item.implicitHeight : 0

    width: implicitWidth
    height: implicitHeight

    Loader {
        id: loader

        source: BarRegistry.source(root.moduleId)

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
