pragma Singleton

import Quickshell
import "../core"

Singleton {
    id: root

    readonly property string username:
        Quickshell.env("USER") || Quickshell.env("LOGNAME") || "User"

    readonly property string hostname:
        Quickshell.env("HOSTNAME") || "Linux"

    readonly property string desktop:
        Quickshell.env("XDG_CURRENT_DESKTOP") || "Hyprland"

    function launchCandidates(commands, label) {
        const names = commands.join(" ")

        const script = `
            for app in ${names}; do
                if command -v "$app" >/dev/null 2>&1; then
                    exec "$app"
                fi
            done

            if command -v notify-send >/dev/null 2>&1; then
                notify-send "Wayck" "${label} não está instalado."
            fi
        `

        Quickshell.execDetached(["sh", "-c", script])
    }

    function openSettings(section) {
        switch (section) {
        case "hyprland":
            Quickshell.execDetached([
                "xdg-open",
                Quickshell.env("HOME") + "/.config/hypr"
            ])
            break

        case "displays":
            launchCandidates(
                ["nwg-displays", "wdisplays"],
                "Gerenciador de monitores"
            )
            break

        case "network":
            launchCandidates(
                ["nm-connection-editor"],
                "Gerenciador de rede"
            )
            break

        case "audio":
            launchCandidates(
                ["pavucontrol", "pavucontrol-qt", "pwvucontrol"],
                "Controle de áudio"
            )
            break

        case "bluetooth":
            launchCandidates(
                ["overskride", "blueman-manager"],
                "Gerenciador Bluetooth"
            )
            break

        case "appearance":
            Quickshell.execDetached([
                "micro",
                Config.path
            ])
            break

        case "system":
            launchCandidates(
                ["systemsettings", "gnome-control-center", "cosmic-settings"],
                "Configurações do sistema"
            )
            break

        case "monitor":
            launchCandidates(
                ["mission-center", "gnome-system-monitor", "xfce4-taskmanager"],
                "Monitor do sistema"
            )
            break
        }
    }

    function executePower(action) {
        switch (action) {
        case "lock":
            Quickshell.execDetached([
                "sh", "-c",
                'if command -v hyprlock >/dev/null 2>&1; then exec hyprlock; else loginctl lock-session; fi'
            ])
            break

        case "suspend":
            Quickshell.execDetached([
                "sh", "-c",
                'if command -v hyprlock >/dev/null 2>&1; then hyprlock & sleep 1; else loginctl lock-session; fi; systemctl suspend'
            ])
            break

        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"])
            break

        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"])
            break

        case "logout":
            Quickshell.execDetached([
                "sh", "-c",
                'if command -v uwsm >/dev/null 2>&1 && uwsm check is-active hyprland >/dev/null 2>&1; then exec uwsm stop; elif command -v hyprshutdown >/dev/null 2>&1; then exec hyprshutdown; else exec hyprctl dispatch exit; fi'
            ])
            break
        }
    }
}
