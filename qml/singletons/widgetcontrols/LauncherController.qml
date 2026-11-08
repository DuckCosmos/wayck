pragma Singleton
import Quickshell
import QtQuick
import Quickshell.Io

Singleton {
    id: root

    property bool open: false

    function toggle(): void { open ? hide() : show() }
    function show(): void { open = true }
    function hide(): void { open = false }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle() }
        function open(): void { root.show() }
        function close(): void { root.hide() }
    }
}