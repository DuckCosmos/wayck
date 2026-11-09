pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string colorsPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/quickshell/user/generated/colors.json"

    property var raw: ({})

    function pick(key, fallback) {
        const value = raw[key]
        return value ? value : fallback
    }

    readonly property color background:              pick("background", "#201a18")
    readonly property color surface:                  pick("surface", "#201a18")
    readonly property color backgroundForeground:    pick("on_background", "#ede0dc")
    readonly property color surfaceForeground:       pick("on_surface", "#ede0dc")
    readonly property color surfaceVariantForeground: pick("on_surface_variant", "#d5c3bc")
    readonly property color surfaceVariant:           pick("surface_variant", "#51443f")
    readonly property color surfaceContainerLowest:   pick("surface_container_lowest", "#150f0d")
    readonly property color surfaceContainerLow:      pick("surface_container_low", "#292321")
    readonly property color surfaceContainer:        pick("surface_container", "#322824")
    readonly property color surfaceContainerHigh:    pick("surface_container_high", "#322824")
    readonly property color surfaceContainerHighest: pick("surface_container_highest", "#3d322e")

    readonly property color primary:                  pick("primary", "#ffb59b")
    readonly property color onPrimary:                pick("on_primary", "#55200a")
    readonly property color primaryContainer:         pick("primary_container", "#73351e")
    readonly property color onPrimaryContainer:       pick("on_primary_container", "#ffdbce")
    readonly property color secondary:                pick("secondary", "#e7bdae")
    readonly property color onSecondary:              pick("on_secondary", "#442a20")
    readonly property color tertiary:                pick("tertiary", "#d5c58d")
    readonly property color onTertiary:               pick("on_tertiary", "#393016")
    readonly property color error:                    pick("error", "#ffb4ab")
    readonly property color onError:                  pick("on_error", "#690005")
    readonly property color outline:                  pick("outline", "#a08d86")
    readonly property color outlineVariant:            pick("outline_variant", "#51443f")

    FileView {
        path: root.colorsPath
        watchChanges: true

        onFileChanged: reload()

        onLoaded: {
            try {
                const parsed = JSON.parse(text())
                root.raw = parsed && parsed.colors ? parsed.colors : parsed
            } catch (e) {
                console.warn("[Theme] colors.json inválido:", e)
            }
        }
    }
}