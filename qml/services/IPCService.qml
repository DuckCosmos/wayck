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


    property var barHandler: IpcHandler {
        target: "bar"
        function toggle(): void { BarService.toggle() }
        function show(): void { BarService.show() }
        function hide(): void { BarService.hide() }
    }
}