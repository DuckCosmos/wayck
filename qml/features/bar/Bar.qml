import QtQuick
import Quickshell
import Quickshell.Wayland

import "."
import "components" as Components

// Barra responsiva do Wayck.
//
// Como ela "cabe perfeitamente" em qualquer largura (do mais folgado pro mais apertado):
//   1. ESTICA   -> sobra espaço: afasta os módulos (até maxModuleSpacing)
//   2. NORMAL   -> espaçamento mínimo
//   3. COMPACTA -> falta espaço: módulos diminuem padding/espaços (compactness = 1)
//   4. ESCONDE  -> ainda falta: some o módulo de MENOR prioridade (BarRegistry),
//                  um por vez, e volta quando há folga de novo.
PanelWindow {
    id: root

    signal dismissed()

    // ---------- Limites do layout ----------
    readonly property real minModuleSpacing: 4
    readonly property real maxModuleSpacing: 10
    readonly property real sectionGap: 8      // vão mínimo entre esquerda/centro/direita
    readonly property real hysteresis: 20     // folga extra pra reexibir (evita pisca-pisca)

    // ---------- Estado do ajuste ----------
    property bool compact: false
    property int hiddenCount: 0               // quantos módulos estão escondidos
    property var hiddenIds: ({})              // { id: true }
    property string hiddenKey: ""
    property real moduleSpacing: minModuleSpacing

    property real compactSavings: 0           // quanto o modo compacto economizou (medido)
    property real preCompactNeed: 0

    // Animada: o padding dos módulos "respira" em vez de dar salto.
    property real compactness: compact ? 1 : 0

    Behavior on compactness {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool debug: Quickshell.env("WAYCK_DEBUG") === "1"

    // ---------- Janela ----------
    color: "transparent"

    implicitHeight: BarConfig.barHeight
    exclusiveZone: BarConfig.barHeight

    WlrLayershell.namespace: "wayck-bar"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: BarConfig.position === "top"
        bottom: BarConfig.position === "bottom"
        left: true
        right: true
    }

    margins {
        left: BarConfig.edgeMargin
        right: BarConfig.edgeMargin
    }

    // ---------- Medição ----------
    // Lista { id, section, w, priority, order } de todos os módulos carregados.
    function collect() {
        const infos = []

        for (const section of [leftSection, centerSection, rightSection]) {
            for (const slot of section.slots()) {
                if (slot.implicitWidth <= 0)
                    continue

                infos.push({
                    id: slot.moduleId,
                    section: section.sectionName,
                    w: slot.implicitWidth,
                    priority: slot.priority,
                    order: slot.order
                })
            }
        }

        return infos
    }

    // Largura mínima necessária pra mostrar `list` (espaçamento no mínimo).
    function needFor(list) {
        const counts = { left: 0, center: 0, right: 0 }
        let sum = 0

        for (const m of list) {
            sum += m.w
            counts[m.section]++
        }

        let moduleGaps = 0
        let usedSections = 0

        for (const key of ["left", "center", "right"]) {
            if (counts[key] > 0) {
                usedSections++
                moduleGaps += counts[key] - 1
            }
        }

        return {
            total: sum + moduleGaps * minModuleSpacing
                + Math.max(0, usedSections - 1) * sectionGap,
            moduleGaps: moduleGaps
        }
    }

    // ---------- Decisão ----------
    function evaluate() {
        const avail = barContent.width

        if (avail <= 0)
            return

        const infos = collect()

        if (infos.length === 0)
            return

        // Ordem de sacrifício: menor prioridade primeiro; empate => o mais à direita.
        const sacrifice = infos.slice().sort(
            (a, b) => (a.priority - b.priority) || (b.order - a.order)
        )

        const maxHidden = Math.max(0, sacrifice.length - 1)   // nunca esconde tudo

        function visibleAfter(count) {
            const gone = {}

            for (let i = 0; i < count; i++)
                gone[sacrifice[i].id] = true

            return infos.filter(m => gone[m.id] !== true)
        }

        let hidden = Math.min(hiddenCount, maxHidden)
        let nextCompact = compact

        let need = needFor(visibleAfter(hidden)).total

        // Mede (uma vez) quanto o modo compacto economizou, já com as larguras assentadas.
        if (nextCompact && preCompactNeed > 0) {
            compactSavings = Math.max(0, preCompactNeed - need)
            preCompactNeed = 0
        }

        if (need > avail) {
            if (!nextCompact) {
                // 3. Primeiro tenta compactar.
                preCompactNeed = need
                nextCompact = true
            } else {
                // 4. Já compacto e ainda não cabe: esconde os menos importantes.
                let deficit = need - avail

                while (deficit > 0 && hidden < maxHidden) {
                    deficit -= sacrifice[hidden].w + minModuleSpacing
                    hidden++
                }
            }
        } else {
            const slack = avail - need

            if (hidden > 0) {
                // Volta o módulo mais importante dos escondidos, se sobrar espaço com folga.
                if (slack >= sacrifice[hidden - 1].w + minModuleSpacing + hysteresis)
                    hidden--
            } else if (nextCompact && slack >= Math.max(compactSavings, 8) + hysteresis) {
                nextCompact = false
            }
        }

        const changed = hidden !== hiddenCount || nextCompact !== compact

        hiddenCount = hidden
        compact = nextCompact

        // Aplica quem está escondido (só reatribui se mudou).
        const hiddenNow = sacrifice.slice(0, hidden)
        const key = hiddenNow.map(m => m.id).join(",")

        if (key !== hiddenKey) {
            hiddenKey = key

            const map = {}

            for (const m of hiddenNow)
                map[m.id] = true

            hiddenIds = map
        }

        // 1. ESTICA: usa metade da folga pra afastar os módulos (com teto).
        const info = needFor(visibleAfter(hidden))
        const extra = Math.max(0, avail - info.total)

        moduleSpacing = info.moduleGaps > 0
            ? Math.min(maxModuleSpacing, minModuleSpacing + extra * 0.5 / info.moduleGaps)
            : minModuleSpacing

        if (debug) {
            console.log("[WAYCK BAR]",
                "avail:", Math.round(avail),
                "need:", Math.round(need),
                "compact:", compact,
                "hidden:", key || "-",
                "spacing:", moduleSpacing.toFixed(1))
        }

        // Mudou o estado => reavalia depois que as larguras assentarem.
        if (changed)
            layoutTimer.restart()
    }

    // Debounce: espera as larguras pararem de mudar (animações, módulos carregando).
    Timer {
        id: layoutTimer

        interval: 80
        repeat: false
        onTriggered: root.evaluate()
    }

    function scheduleLayout() {
        layoutTimer.restart()
    }

    Connections {
        target: BarConfig

        function onLeftModulesChanged() { root.scheduleLayout() }
        function onCenterModulesChanged() { root.scheduleLayout() }
        function onRightModulesChanged() { root.scheduleLayout() }
    }

    Component.onCompleted: scheduleLayout()

    // ---------- Conteúdo ----------
    Item {
        id: barContent

        anchors.fill: parent

        onWidthChanged: root.scheduleLayout()

        // Limites pro centro nunca invadir esquerda/direita.
        readonly property real leftEdge:
            leftSection.width > 0 ? leftSection.width + root.sectionGap : 0

        readonly property real rightEdge:
            rightSection.width > 0 ? rightSection.x - root.sectionGap : width

        readonly property real idealCenterX: (width - centerSection.width) / 2
        readonly property real maxCenterX: rightEdge - centerSection.width

        Components.BarSection {
            id: leftSection

            sectionName: "left"
            model: BarConfig.leftModules
            firstOrder: 0
            hiddenIds: root.hiddenIds
            compactness: root.compactness
            spacing: root.moduleSpacing
            height: barContent.height

            x: 0

            onMetricsChanged: root.scheduleLayout()
        }

        Components.BarSection {
            id: centerSection

            sectionName: "center"
            model: BarConfig.centerModules
            firstOrder: BarConfig.leftModules.length
            hiddenIds: root.hiddenIds
            compactness: root.compactness
            spacing: root.moduleSpacing
            height: barContent.height

            // Centralizado na tela, mas "empurrado" se esquerda/direita crescerem.
            x: Math.max(barContent.leftEdge, Math.min(barContent.idealCenterX, barContent.maxCenterX))

            onMetricsChanged: root.scheduleLayout()
        }

        Components.BarSection {
            id: rightSection

            sectionName: "right"
            model: BarConfig.rightModules
            firstOrder: BarConfig.leftModules.length + BarConfig.centerModules.length
            hiddenIds: root.hiddenIds
            compactness: root.compactness
            spacing: root.moduleSpacing
            height: barContent.height

            x: barContent.width - width

            onMetricsChanged: root.scheduleLayout()
        }
    }
}
