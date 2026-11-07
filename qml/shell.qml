//@ pragma UseQApplication
//@ pragma IconTheme Papirus

import QtQuick
import Quickshell
import Quickshell.Io
import "core"
import "services"
import "features/bar" as BarUI
import "features/clipboard" as ClipboardUI
import "features/launcher" as LauncherUI

ShellRoot {
    id: root

    readonly property var screenshotService: ScreenshotService
    readonly property var notificationService: NotificationService


    property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    Process {
        running: true
        command: ["sh", "-c", "rm -f /tmp/wayck_clip_*.png"]
    }

    Process {
        running: root.isHyprland && Config.blur
        command: ["hyprctl", "eval", "hl.config({ decoration = { blur = { enabled = true } } })"]
    }

    Process {
        running: root.isHyprland && Config.blur
        command: ["hyprctl", "eval", "hl.layer_rule({ name='wayck-launcher-blur', match={namespace='^wayck-launcher$'}, blur=true, ignore_alpha=0 })"]
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

        LauncherUI.Launcher {
            blurEnabled: Config.blur
            onDismissed: LauncherService.hide()
        }
    }

    LazyLoader {
        id: clipboardLoader
        active: ClipboardService.open

        ClipboardUI.Clipboard {
            onDismissed: ClipboardService.hide()
        }
    }

    LazyLoader {
        id: barLoader
        active: BarService.open

        BarUI.Bar {
            onDismissed: BarService.hide()
        }
    }
}
