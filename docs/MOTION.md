# Wayck Motion System

The motion system is built around shared tokens and reusable QML surfaces. Components describe their semantic states and geometry while the shared primitives handle interpolation and timing.

## Motion tokens

Use the `Motion` singleton instead of hard-coding durations and easing curves.

```qml
Behavior on opacity {
    NumberAnimation {
        duration: Motion.contentFadeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Motion.contentCurve
    }
}
```

The token groups cover general-purpose timing, pointer feedback, surface transitions, layout movement and content reveal. Tune them centrally; avoid unrelated durations per widget.

## Hover deformation with BarCard

`BarCard` provides reusable hover deformation without changing its implicit layout size.

```qml
BarCard {
    hoverEnabled: true
    hoverScale: 1.035
    hoverRadiusBoost: 3

    Text { text: "Volume" }
}
```

Set `hoverEnabled: false` for decorative cards or when a parent owns pointer interaction.

## MorphSurface

Use `MorphSurface` when compact and expanded content belong to the same visual surface. It interpolates one normalized progress value for position, size, radius and scale. For a cross-window handoff, use the shared overlay host rather than reparenting a `QQuickItem`.

## Shared morph host: player and system tray

Player and tray use a per-monitor `PanelWindow` overlay. The source icon is captured with `Item.grabToImage()`; the `ItemGrabResult` is retained while its URL is displayed. When a snapshot cannot be created, the controller still opens the expanded surface instead of silently abandoning the interaction.

The player opens after a short hover dwell on its album-art area, or immediately on click. It also opens when there is no active player, showing the empty-player state. The destination is centered around the source icon and grows from that exact rectangle.

The system tray opens a native item menu after a hover dwell, or immediately on click. Items without a native menu retain their normal activation behavior. The tray destination is anchored to the originating icon, growing upward from a bottom bar and downward from a top bar. The native menu lives inside the morph surface instead of a separate popup window.

The hover-close timer only starts after the overlay has actually received a pointer-enter event and then a pointer-leave event. This prevents a newly created overlay from closing simply because the pointer state has not yet propagated to its new window.

## Adding a new morph surface

1. Give the compact face a stable source `Item` with a non-zero visible size.
2. Call `MorphController.open(sourceItem, "surface-id", payload)` on hover or click.
3. Register the expanded component in `MorphOverlay.qml` and pass its payload through `MorphController.surfaceData`.
4. Choose destination geometry that contains the pointer's original position.
5. Keep the close path connected to `MorphController.close()`.

Use the `Motion` singleton for timing and easing. Keep geometry transition and content reveal phase-locked through the same `MorphSurface.progress`.

## Cross-window constraints

A `PanelWindow` is a distinct Wayland surface. Use a retained snapshot as the bridge between the source window and the overlay window; do not attempt to move the source `QQuickItem` between windows.

The overlay uses `QsWindow.mask` and a `Region` tied to the morph surface so that the full-screen layer window does not claim pointer input outside the animated shape.

## Design references

The visual language is informed by Caelestia, HakuSpace and Serpantinum. These are design references; check each upstream project's license before copying implementation code.
