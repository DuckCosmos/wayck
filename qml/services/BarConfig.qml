pragma Singleton

import QtQuick
import QtCore
import Quickshell

Singleton {
    id: root

    readonly property var catalog: [
        { id: "workspaces", name: "Workspaces" },
        { id: "player", name: "Player" },
        { id: "audio", name: "Audio" },
        { id: "clock", name: "Clock" },
        { id: "tray", name: "System Tray" },

        { id: "cpu", name: "CPU" },
        { id: "ram", name: "RAM" },
        { id: "gpu", name: "GPU" },
        { id: "disk", name: "Disk" },
        { id: "network", name: "Network" },
        { id: "temperature", name: "Temperature" },
        { id: "usermenu", name: "User Menu" }
]

    readonly property string configDirectory: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME")
        const home = Quickshell.env("HOME")

        return (xdg || home + "/.config") + "/quickshell/wayck"
    }

    Settings {
        id: settings

        location: "file://" + root.configDirectory + "/bar.ini"
        category: "Bar"

        property string left: "workspaces,player,ram,disk"
        property string center: "cpu,clock,gpu,temperature"
        property string right: "network,audio,tray,usermenu"
    }

    function isKnown(id) {
        return catalog.some(module => module.id === id)
    }

    function decode(value) {
        const result = []

        for (const id of (value || "").split(",")) {
            const clean = id.trim()

            if (isKnown(clean) && !result.includes(clean))
                result.push(clean)
        }

        return result
    }

    readonly property var leftModules: decode(settings.left)
    readonly property var centerModules: decode(settings.center)
    readonly property var rightModules: decode(settings.right)

    function sectionFor(id) {
        if (leftModules.includes(id)) return "left"
        if (centerModules.includes(id)) return "center"
        if (rightModules.includes(id)) return "right"

        return ""
    }

    function isEnabled(id) {
        return sectionFor(id) !== ""
    }

    function saveLayout(layout) {
        settings.left = layout.left.join(",")
        settings.center = layout.center.join(",")
        settings.right = layout.right.join(",")
    }

    function setEnabled(id, section, enabled) {
        if (!isKnown(id))
            return

        if (!["left", "center", "right"].includes(section))
            return

        const next = {
            left: [...leftModules],
            center: [...centerModules],
            right: [...rightModules]
        }

        next.left = next.left.filter(x => x !== id)
        next.center = next.center.filter(x => x !== id)
        next.right = next.right.filter(x => x !== id)

        if (enabled)
            next[section].push(id)

        saveLayout(next)
    }

    function setOrder(section, ids) {
        if (!["left", "center", "right"].includes(section))
            return

        const next = {
            left: [...leftModules],
            center: [...centerModules],
            right: [...rightModules]
        }

        const ordered = []

        for (const id of ids) {
            if (isKnown(id) && !ordered.includes(id))
                ordered.push(id)
        }

        next.left = next.left.filter(id => !ordered.includes(id))
        next.center = next.center.filter(id => !ordered.includes(id))
        next.right = next.right.filter(id => !ordered.includes(id))

        next[section] = ordered

        saveLayout(next)
    }

    function move(id, section, index) {
        if (!isKnown(id))
            return

        if (!["left", "center", "right"].includes(section))
            return

        const next = {
            left: [...leftModules],
            center: [...centerModules],
            right: [...rightModules]
        }

        next.left = next.left.filter(x => x !== id)
        next.center = next.center.filter(x => x !== id)
        next.right = next.right.filter(x => x !== id)

        const target = next[section]

        const position = Math.max(
            0,
            Math.min(target.length, Number(index) || 0)
        )

        target.splice(position, 0, id)

        saveLayout(next)
    }

    function reset() {
        settings.left = "workspaces"
        settings.center = "player"
        settings.right = "audio,clock,tray"
    }
}
