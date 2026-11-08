pragma Singleton

import QtQuick
import Quickshell
import "../"

Singleton {
    id: root

    readonly property var types: ({
        "workspaces":  { name: "Workspaces",  face: "faces/workspaces/WorkspacesFace.qml",   priority: 100 },
        "player":      { name: "Player",      face: "faces/player/PlayerFace.qml",           priority: 50 },
        "audio":       { name: "Audio",       face: "faces/audio/AudioFace.qml",             priority: 80 },
        "clock":       { name: "Clock",       face: "faces/clock/ClockFace.qml",             priority: 90 },
        "tray":        { name: "System Tray", face: "faces/tray/TrayFace.qml",               priority: 60 },
        "cpu":         { name: "CPU",         face: "faces/cpu/CpuFace.qml",                 priority: 40 },
        "ram":         { name: "RAM",         face: "faces/ram/RamFace.qml",                 priority: 38 },
        "gpu":         { name: "GPU",         face: "faces/gpu/GpuFace.qml",                 priority: 36 },
        "disk":        { name: "Disk",        face: "faces/disk/DiskFace.qml",               priority: 30 },
        "network":     { name: "Network",     face: "faces/network/NetworkFace.qml",         priority: 70 },
        "temperature": { name: "Temperature", face: "faces/temperature/TemperatureFace.qml", priority: 34 },
        "usermenu":    { name: "User Menu",   face: "faces/usermenu/UserMenuFace.qml",       priority: 65 }
    })

    readonly property var ids: Object.keys(types)

    function normalizeId(id) {
        return String(id || "").toLowerCase().trim()
    }

    function has(id) {
        return Object.prototype.hasOwnProperty.call(types, normalizeId(id))
    }

    // Nome do módulo no idioma atual (chave "modules.<id>"; "name" do types é o alternativo).
    function name(id) {
        if (!has(id))
            return String(id)

        const key = normalizeId(id)

        return I18n.t("modules." + key, types[key].name)
    }

    function priority(id) {
        return has(id) ? types[normalizeId(id)].priority : 0
    }

    function faceFile(id) {
        return has(id) ? Qt.resolvedUrl(types[normalizeId(id)].face) : ""
    }
}
