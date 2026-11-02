import QtQuick
import Quickshell.Io

QtObject {
    property var clipboardHandler: IpcHandler {
        target: "clipboard"
        function toggle(): void { ClipboardService.toggle() }
        function show(): void { ClipboardService.show() }
        function hide(): void { ClipboardService.hide() }
    }

    property var launcherHandler: IpcHandler {
        target: "launcher"
        function toggle(): void { LauncherService.toggle() }
    }
}