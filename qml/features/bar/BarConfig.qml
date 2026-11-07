pragma Singleton

import QtQuick
import Quickshell
import "../../core"
import "."

// API da barra por cima do Config (core/Config.qml).
// Quais módulos EXISTEM vem do BarRegistry; aqui só ficam ONDE cada um está
// e a aparência da barra, sempre validadas.
Singleton {
    id: root

    readonly property var sections: ["left", "center", "right"]

    // Lista pra UI de configuração (id + nome).
    readonly property var catalog: BarRegistry.ids.map(id => ({
        id: id,
        name: BarRegistry.name(id)
    }))

    // ---- Aparência (já validada) ----
    readonly property string position: Config.bar.position === "bottom" ? "bottom" : "top"
    readonly property int barHeight: Math.max(30, Math.min(80, Number(Config.bar.height) || 45))
    readonly property int edgeMargin: Math.max(0, Math.min(40, Number(Config.bar.margin) || 0))

    // ---- Layout ----
    function isKnown(id) {
        return BarRegistry.has(id)
    }

    // Aceita array ou "a,b,c"; devolve só ids conhecidos, sem repetir.
    function decode(value) {
        const raw = Array.isArray(value) ? value : String(value || "").split(",")
        const result = []

        for (const item of raw) {
            const id = String(item).trim()

            if (isKnown(id) && !result.includes(id))
                result.push(id)
        }

        return result
    }

    readonly property var leftModules: decode(Config.bar.layout.left)
    readonly property var centerModules: decode(Config.bar.layout.center)
    readonly property var rightModules: decode(Config.bar.layout.right)

    function layout() {
        return {
            left: [...leftModules],
            center: [...centerModules],
            right: [...rightModules]
        }
    }

    function sectionFor(id) {
        if (leftModules.includes(id)) return "left"
        if (centerModules.includes(id)) return "center"
        if (rightModules.includes(id)) return "right"

        return ""
    }

    function isEnabled(id) {
        return sectionFor(id) !== ""
    }

    function saveLayout(next) {
        Config.bar.layout.left = next.left
        Config.bar.layout.center = next.center
        Config.bar.layout.right = next.right
    }

    function removeFromAll(next, id) {
        for (const section of sections)
            next[section] = next[section].filter(x => x !== id)
    }

    function setEnabled(id, section, enabled) {
        if (!isKnown(id) || !sections.includes(section))
            return

        const next = layout()
        removeFromAll(next, id)

        if (enabled)
            next[section].push(id)

        saveLayout(next)
    }

    function setOrder(section, ids) {
        if (!sections.includes(section))
            return

        const ordered = []

        for (const id of ids) {
            if (isKnown(id) && !ordered.includes(id))
                ordered.push(id)
        }

        const next = layout()

        for (const id of ordered)
            removeFromAll(next, id)

        next[section] = ordered

        saveLayout(next)
    }

    function move(id, section, index) {
        if (!isKnown(id) || !sections.includes(section))
            return

        const next = layout()
        removeFromAll(next, id)

        const target = next[section]
        const position = Math.max(0, Math.min(target.length, Number(index) || 0))

        target.splice(position, 0, id)

        saveLayout(next)
    }

    function reset() {
        saveLayout({
            left: [...Config.barDefaults.left],
            center: [...Config.barDefaults.center],
            right: [...Config.barDefaults.right]
        })
    }
}
