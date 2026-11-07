
pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    Process {
        id: fullProcess

        command: [
            "sh", "-c",
            'mkdir -p "$HOME/Pictures/Screenshots" && ' +
            'grim "$HOME/Pictures/Screenshots from $(date \'+%Y-%m-%d %H-%M-%S\').png"'
        ]
    }

    Process {
        id: regionProcess

        command: [
            "sh", "-c",
            'mkdir -p "$HOME/Pictures/Screenshots" && ' +
            'grim -g "$(slurp)" "$HOME/Pictures/Screenshots from $(date \'+%Y-%m-%d %H-%M-%S\').png"'
        ]
    }

    function full(): void {
        if (!fullProcess.running)
            fullProcess.running = true
    }

    function region(): void {
        if (!regionProcess.running)
            regionProcess.running = true
    }

    IpcHandler {
        target: "screenshot"

        function full(): void {
            root.full()
        }

        function region(): void {
            root.region()
        }
    }
}
