import QtQuick

// Uma seção da barra (esquerda, centro ou direita).
// Um Row já posiciona os filhos lado a lado e ignora os que estão invisíveis,
// então não precisamos calcular x na mão.
Row {
    id: root

    property var model: []             // lista de ids de módulos
    property var hiddenIds: ({})       // { id: true } dos escondidos
    property real compactness: 0
    property string sectionName: ""
    property int firstOrder: 0

    // Disparado quando o tamanho de qualquer módulo muda.
    signal metricsChanged()

    spacing: 6

    // Slots já criados (pro Bar medir).
    function slots() {
        const result = []

        for (let i = 0; i < repeater.count; i++) {
            const slot = repeater.itemAt(i)

            if (slot)
                result.push(slot)
        }

        return result
    }

    Repeater {
        id: repeater

        model: root.model

        delegate: ModuleSlot {
            required property var modelData
            required property int index

            moduleId: modelData
            sectionName: root.sectionName
            order: root.firstOrder + index
            compactness: root.compactness
            shown: root.hiddenIds[modelData] !== true

            // Centraliza verticalmente dentro da barra.
            y: (root.height - height) / 2

            onImplicitWidthChanged: root.metricsChanged()
            Component.onCompleted: root.metricsChanged()
        }
    }
}
