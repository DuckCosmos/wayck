pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Singleton {
    id: root

    readonly property string notificationColor: {
        const c = Theme.primary

        const hex = value => {
            const result = Math.round(value * 255).toString(16)
            return result.length === 1 ? "0" + result : result
        }

        return `#${hex(c.r)}${hex(c.g)}${hex(c.b)}`
    }

    property var queue: []

    readonly property string script: [
        'set -Eeuo pipefail',
        'title="$1"',
        'body="$2"',
        'notification_color="$3"',
        '[[ "$notification_color" =~ ^#[[:xdigit:]]{6}$ ]] || notification_color="#444444"',
        'command -v notify-send >/dev/null 2>&1 || exit 0',
        'source_icon="/usr/share/icons/Papirus/22x22/actions/stock_bell.svg"',
        'icon_dir="${XDG_CACHE_HOME:-$HOME/.cache}/wayck"',
        'color_hex="${notification_color:1}"',
        'icon="$icon_dir/notification-bell-${color_hex}.svg"',
        'tmp="$icon.tmp.$$"',
        'if [ -r "$source_icon" ]; then',
        '    mkdir -p "$icon_dir" || exit 0',
        '    if [ ! -s "$icon" ]; then',
        '        if ! sed "s/#444444/${notification_color}/g" "$source_icon" > "$tmp"; then',
        '            rm -f "$tmp"',
        '            exit 0',
        '        fi',
        '        mv "$tmp" "$icon" || { rm -f "$tmp"; exit 0; }',
        '    fi',
        '    notify-send --app-name="Wayck" --app-icon="$icon" --expire-time=5000 "$title" "$body" || true',
        'else',
        '    notify-send --app-name="Wayck" --expire-time=5000 "$title" "$body" || true',
        'fi'
    ].join("\n")

    function send(title: string, body: string): void {
        const next = queue.slice()
        next.push({ title, body })
        queue = next
        startNext()
    }

    function startNext(): void {
        if (notificationProcess.running || queue.length === 0)
            return

        const next = queue[0]
        queue = queue.slice(1)

        notificationProcess.title = next.title
        notificationProcess.body = next.body
        notificationProcess.running = true
    }

    Process {
        id: notificationProcess

        property string title: ""
        property string body: ""

        onExited: Qt.callLater(root.startNext)

        command: [
            "bash",
            "-c",
            root.script,
            "wayck-notification",
            title,
            body,
            root.notificationColor
        ]
    }
}
