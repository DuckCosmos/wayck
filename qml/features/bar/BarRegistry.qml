pragma Singleton

import QtQuick
import Quickshell

// Catálogo de módulos da barra.
// Módulo novo = 1) criar modules/Foo.qml  2) adicionar UMA linha aqui.
// Nada mais precisa mudar (Bar, BarConfig e ModuleSlot leem daqui).
//
//   name     -> nome mostrado nas configurações
//   file     -> arquivo dentro de modules/
//   priority -> quanto MAIOR, mais importante. Quando a tela fica pequena,
//               a barra esconde primeiro os de menor prioridade.
Singleton {
    id: root

    readonly property var modules: ({
        "workspaces":  { name: "Workspaces",   file: "Workspaces.qml",  priority: 100 },
        "player":      { name: "Player",       file: "Player.qml",      priority: 50 },
        "audio":       { name: "Audio",        file: "Audio.qml",       priority: 80 },
        "clock":       { name: "Clock",        file: "Clock.qml",       priority: 90 },
        "tray":        { name: "System Tray",  file: "Tray.qml",        priority: 60 },
        "cpu":         { name: "CPU",          file: "CPU.qml",         priority: 40 },
        "ram":         { name: "RAM",          file: "RAM.qml",         priority: 38 },
        "gpu":         { name: "GPU",          file: "GPU.qml",         priority: 36 },
        "disk":        { name: "Disk",         file: "Disk.qml",        priority: 30 },
        "network":     { name: "Network",      file: "Network.qml",     priority: 70 },
        "temperature": { name: "Temperature",  file: "Temperature.qml", priority: 34 },
        "usermenu":    { name: "User Menu",    file: "UserMenu.qml",    priority: 65 }
    })

    readonly property var ids: Object.keys(modules)

    function has(id) {
        return Object.prototype.hasOwnProperty.call(modules, id)
    }

    function name(id) {
        return has(id) ? modules[id].name : id
    }

    function priority(id) {
        return has(id) ? modules[id].priority : 0
    }

    // Qt.resolvedUrl resolve relativo a ESTE arquivo (features/bar/).
    function source(id) {
        return has(id) ? Qt.resolvedUrl("modules/" + modules[id].file) : ""
    }
}
