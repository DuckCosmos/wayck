pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string backendCommand:
        Quickshell.env("WAYCK_WALLPAPER") || "wayck-wallpaper"

    property var wallpapers: []
    property string currentWallpaper: ""
    property int selectedIndex: -1

    property bool opened: false
    property bool refreshing: false
    property bool applying: false
    property string status: ""

    readonly property string selectedWallpaper:
        selectedIndex >= 0 && selectedIndex < wallpapers.length
            ? wallpapers[selectedIndex]
            : ""

    function open(): void {
        opened = true
        refresh()
    }

    function close(): void {
        opened = false
    }

    function toggle(): void {
        if (opened)
            close()
        else
            open()
    }

    function refresh(): void {
        if (applying)
            return

        refreshing = true
        status = "Carregando wallpapers..."

        if (!listProcess.running)
            listProcess.running = true

        if (!currentProcess.running)
            currentProcess.running = true
    }

    function syncSelectedIndex(): void {
        if (wallpapers.length === 0) {
            selectedIndex = -1
            return
        }

        const currentIndex = wallpapers.indexOf(currentWallpaper)

        if (currentIndex >= 0) {
            selectedIndex = currentIndex
            return
        }

        selectedIndex = Math.max(0, Math.min(selectedIndex, wallpapers.length - 1))
    }

    function selectIndex(index: int): void {
        if (wallpapers.length === 0)
            return

        selectedIndex = Math.max(0, Math.min(index, wallpapers.length - 1))
    }

    function select(path: string): void {
        const index = wallpapers.indexOf(path)

        if (index >= 0)
            selectIndex(index)
    }

    function next(): void {
        if (wallpapers.length < 2)
            return

        selectIndex((selectedIndex + 1 + wallpapers.length) % wallpapers.length)
    }

    function previous(): void {
        if (wallpapers.length < 2)
            return

        selectIndex((selectedIndex - 1 + wallpapers.length) % wallpapers.length)
    }

    function apply(): void {
        if (applying || selectedWallpaper.length === 0)
            return

        status = "Aplicando wallpaper..."
        applying = true
        applyProcess.targetPath = selectedWallpaper
        applyProcess.running = true
    }

    Process {
        id: listProcess

        command: [root.backendCommand, "list"]

        stdout: StdioCollector {
            id: listOutput
        }

        stderr: StdioCollector {
            id: listErrors
        }

        onExited: exitCode => {
            if (exitCode !== 0) {
                const problem = listErrors.text.trim()
                root.status = problem || "Não foi possível listar os wallpapers."
                root.wallpapers = []
                root.selectedIndex = -1
                root.refreshing = false
                console.warn("[WallpaperService] list falhou:", root.status)
                return
            }

            const output = listOutput.text.trim()
            root.wallpapers = output.length > 0
                ? output.split(/\r?\n/).filter(path => path.length > 0)
                : []

            root.syncSelectedIndex()
            root.refreshing = false
            root.status = root.wallpapers.length > 0
                ? `${root.wallpapers.length} wallpapers encontrados`
                : "Nenhum wallpaper encontrado."

            console.log("[WallpaperService] wallpapers:", root.wallpapers.length)
        }
    }

    Process {
        id: currentProcess

        command: [root.backendCommand, "current"]

        stdout: StdioCollector {
            id: currentOutput
        }

        stderr: StdioCollector {
            id: currentErrors
        }

        onExited: exitCode => {
            root.currentWallpaper = exitCode === 0
                ? currentOutput.text.trim().split(/\r?\n/)[0]
                : ""

            root.syncSelectedIndex()
        }
    }

    Process {
        id: applyProcess

        property string targetPath: ""

        command: [root.backendCommand, "set", targetPath]

        stdout: StdioCollector {
            id: applyOutput
        }

        stderr: StdioCollector {
            id: applyErrors
        }

        onExited: exitCode => {
            root.applying = false

            if (exitCode === 0) {
                root.currentWallpaper = targetPath
                root.status = "Wallpaper aplicado."
                console.log("[WallpaperService] aplicado:", targetPath)
                root.close()
            } else {
                const problem = applyErrors.text.trim()
                root.status = problem || "Falha ao aplicar o wallpaper."
                console.warn("[WallpaperService] apply falhou:", root.status)
            }
        }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void {
            root.open()
        }

        function close(): void {
            root.close()
        }

        function toggle(): void {
            root.toggle()
        }

        function next(): void {
            root.next()
        }

        function previous(): void {
            root.previous()
        }

        function apply(): void {
            root.apply()
        }

        function refresh(): void {
            root.refresh()
        }
    }
}
