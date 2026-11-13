pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool opened: false

    function open(): void {
        opened = true
    }

    function close(): void {
        opened = false
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            root.open()
        }

        function close(): void {
            root.close()
        }
    }
}