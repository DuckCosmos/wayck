pragma Singleton

import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool open: true

    function toggle(): void { open = !open }
    function show(): void { open = true }
    function hide(): void { open = false }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }
}
