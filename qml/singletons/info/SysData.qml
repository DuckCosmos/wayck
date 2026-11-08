pragma Singleton

import QtQuick

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool connected: false

    property var data: ({
        cpu_percent: 0,
        ram_percent: 0,
        ram_used_mb: 0,
        ram_total_mb: 0,
        disk_percent: 0,
        disk_used_gib: 0,
        disk_total_gib: 0,
        gpu_available: false,
        gpu_percent: null,
        gpu_temp_c: null,
        gpu_vram_percent: null,
        gpu_vram_used_mb: null,
        gpu_vram_total_mb: null,
        network_down_kib_s: 0,
        network_up_kib_s: 0,
        temperature_c: null
    })

    function acceptLine(line) {
        try {
            const parsed = JSON.parse(line)

            if (parsed && typeof parsed === "object") {
                data = parsed
                connected = true
            }
        } catch (error) {
            console.warn("Wayck Monitor: JSON inválido:", error)
        }
    }

    function formatSpeed(kibPerSecond) {
        const value = Math.max(0, Number(kibPerSecond) || 0)

        if (value >= 1024)
            return (value / 1024).toFixed(1) + " MB/s"

        return value.toFixed(0) + " KB/s"
    }

    Process {
        id: monitorProcess

        command: [
            Quickshell.shellPath("wayck-backend"),
            "--monitor"
        ]

        running: false

        Component.onCompleted: running = true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.acceptLine(data)
        }

        stderr: SplitParser {
            onRead: data => console.warn("Wayck Monitor:", data)
        }

        onExited: restartTimer.start()
    }

    Timer {
        id: restartTimer
        interval: 5000
        repeat: false

        onTriggered: monitorProcess.running = true
    }
}
