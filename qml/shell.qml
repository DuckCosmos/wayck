import Quickshell
import Quickshell.Io

ShellRoot {
    id: root

    property bool launcherOpen: false

    property bool isHyprland: !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config")
              + "/wayck/config.json"

        adapter: JsonAdapter {
            id: cfg
            property bool blur: false
        }
    }

    Process {
        running: root.isHyprland && cfg.blur
        command: ["hyprctl", "eval",
            "hl.config({ decoration = { blur = { enabled = true } } })"]
    }

    Process {
        running: root.isHyprland && cfg.blur
        command: ["hyprctl", "eval",
            "hl.layer_rule({ name='wayck-launcher-blur', match={namespace='^wayck-launcher$'}, blur=true, ignore_alpha=0 })"]
    }

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            if (!root.launcherOpen)
                root.launcherOpen = true;
            else if (loader.item)
                loader.item.close();
        }
    }

    LazyLoader {
        id: loader
        active: root.launcherOpen

        Launcher {
            blurEnabled: cfg.blur
            onDismissed: root.launcherOpen = false
        }
    }
}
