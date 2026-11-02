# Wayck Bar architecture migration

This patch replaces the bar's file-path catalog with explicit module slots.
The JSON stores only module IDs and their region/order. Bar.qml owns the fixed
mapping from each ID to a QML file. ModuleSlot loads one known component and
forwards the bar theme.

MediaService and TrayService snapshot the Quickshell ObjectModels when items
are inserted/removed (with a lightweight 1.5 s refresh as a fallback). Player
uses a stable-width single-player card; Tray computes its width from the
service's item snapshot. This avoids relying on a Repeater's own implicit size.

## Files
- qml/services/BarConfig.qml
- qml/services/BarService.qml
- qml/services/MediaService.qml
- qml/services/TrayService.qml
- qml/services/qmldir
- qml/ui/Bar/Bar.qml
- qml/ui/Bar/components/ModuleSlot.qml (+ qmldir)
- qml/ui/Bar/modules/*.qml (+ qmldir)

The user's existing bar-config.json is intentionally not included or
replaced. Its left/center/right arrays remain the source of truth.
