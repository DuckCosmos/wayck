import QtQuick
import Quickshell
import Quickshell.Io
import "services"

ShellRoot {
    id: root

    property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    Process {
        running: true
        command: ["sh", "-c", "rm -f /tmp/wayck_clip_*.png"]
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/wayck/config.json"

        adapter: JsonAdapter {
            id: cfg

            property bool blur: false
        }

    }

    Process {
        running: root.isHyprland && cfg.blur
        command: ["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = true } } })"]
    }

    Process {
        running: root.isHyprland && cfg.blur
        command: ["hyprctl", "eval", "hl.layer_rule({ name='wayck-launcher-blur', match={namespace='^wayck-launcher$'}, blur=true, ignore_alpha=0 })"]
    }

    Process {
        running: root.isHyprland && cfg.blur
        command: ["hyprctl", "eval", "hl.layer_rule({ name='wayck-clipboard-blur', match={namespace='^wayck-clipboard$'}, blur=true, ignore_alpha=0 })"]
    }

    // ---------- Coordenação: só um painel por vez ----------
    Connections {
        function onOpenChanged() {
            if (LauncherService.open && ClipboardService.open) {
                if (clipboardLoader.item)
                    clipboardLoader.item.close();
                else
                    ClipboardService.hide();
            }
        }

        target: LauncherService
    }

    Connections {
        function onOpenChanged() {
            if (ClipboardService.open && LauncherService.open) {
                if (launcherLoader.item)
                    launcherLoader.item.close();
                else
                    LauncherService.hide();
            }
        }

        target: ClipboardService
    }

    // ---------- Loaders ----------
    LazyLoader {
        id: launcherLoader

        active: LauncherService.open

        Launcher {
            blurEnabled: cfg.blur
            onDismissed: LauncherService.hide()
        }

    }

    LazyLoader {
        id: clipboardLoader

        active: ClipboardService.open

        Clipboard {
            blurEnabled: cfg.blur
            onDismissed: ClipboardService.hide()
        }

    }

}
