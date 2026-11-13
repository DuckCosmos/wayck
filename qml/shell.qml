//@ pragma UseQApplication
//@ pragma IconTheme Papirus

import QtQuick
import Quickshell
import Quickshell.Io
import "."

ShellRoot {
    id: root

    readonly property var screenshotController: ScreenshotController
    readonly property var languageController: LanguageController
    readonly property var sysNotif: SysNotif

    readonly property var i18n: I18n

    property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    Process {
        running: true
        command: ["sh", "-c", "rm -f /tmp/wayck_clip_*.png"]
    }

    Process {
        running: root.isHyprland && Config.blur
        command: [
            "hyprctl",
            "eval",
            "hl.config({ decoration = { blur = { enabled = true, size = 2, passes = 2 } } })"
        ]
    }

    Process {
        running: true
        command: [
            "sh",
            "-c",
            "wl-paste --type image --watch cliphist store & wl-paste --type text --watch cliphist store & wait"
        ]
    }

    Process {
        running: root.isHyprland && Config.blur
        command: ["hyprctl", "eval", "hl.layer_rule({ name='wayck-launcher-blur', match={namespace='^wayck-launcher$'}, blur=true, ignore_alpha=0 })"]
    }

    Process {
        running: root.isHyprland && Config.blur
        command: ["hyprctl", "eval", "hl.layer_rule({ name='wayck-wallpaper-selector-blur', match={namespace='^wayck-wallpaper-selector$'}, blur=true, ignore_alpha=0 })"]
    }

    Process {
        running: true
        command: [Quickshell.env("WAYCK_WALLPAPER") || "wayck-wallpaper", "apply"]
        onExited: exitCode => {
            if (exitCode !== 0)
                console.warn("[Wayck] Não foi possível restaurar o wallpaper na inicialização.");
        }
    }

    Connections {
        function onOpenChanged() {
            if (LauncherController.open && ClipboardController.open) {
                if (clipboardLoader.item)
                    clipboardLoader.item.close();
                else
                    ClipboardController.hide();
            }
        }

        target: LauncherController
    }

    Connections {
        function onOpenChanged() {
            if (ClipboardController.open && LauncherController.open) {
                if (launcherLoader.item)
                    launcherLoader.item.close();
                else
                    LauncherController.hide();
            }
        }

        target: ClipboardController
    }

    NotificationPopup {}

    WallpaperEngine {}

    LazyLoader {
        id: wallpaperSelectorLoader
        active: WallpaperService.opened

        WallpaperSelector {
            onDismissed: WallpaperService.close()
        }
    }

    LazyLoader {
        id: launcherLoader
        active: LauncherController.open

        Launcher {
            blurEnabled: Config.blur
            onDismissed: LauncherController.hide()
        }
    }

    LazyLoader {
        id: clipboardLoader
        active: ClipboardController.open

        Clipboard {
            onDismissed: ClipboardController.hide()
        }
    }

    LazyLoader {
        id: barLoader
        active: BarController.open

        Bar {
            onDismissed: BarController.hide()
        }
    }
}
