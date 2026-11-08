# Wayck Motion System

The motion system is built around shared tokens and reusable QML surfaces. The goal is to make motion composable: a component describes its states and geometry, while the shared primitives handle interpolation and timing.

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

Available groups include:
- `fast`, `normal`, `medium`, `slow`: general-purpose durations.
- `hoverDuration`, `hoverEnterCurve`, `hoverExitCurve`: pointer feedback.
- `surfaceOpenDuration`, `surfaceCloseDuration`, `surfaceOpenCurve`, `surfaceCloseCurve`: surface transitions.
- `morphDuration`, `morphCurve`: shape and geometry morphing.
- `layoutDuration`, `layoutCurve`: layout movement.
- `contentFadeDuration`, `contentCurve`: content reveal and concealment.

Change the singleton tokens to tune the shell consistently. Avoid giving every widget unrelated durations.

## Hover deformation with BarCard

`BarCard` has a reusable hover deformation. It changes the rendered scale, corner radius and border treatment without changing its implicit layout size.

```qml
BarCard {
    hoverEnabled: true
    hoverScale: 1.035
    hoverRadiusBoost: 3

    Text {
        text: "Volume"
    }
}
```

Set `hoverEnabled: false` when a card is decorative or when its parent owns pointer interaction. The default is enabled.

## MorphSurface: compact surface to expanded surface

Use `MorphSurface` when a compact representation and its expanded content belong to the same visual surface and the same QQuickWindow.

```qml
MorphSurface {
    id: surface

    expanded: controller.open

    collapsedWidth: 190
    collapsedHeight: 54
    collapsedRadius: 27
    collapsedScale: 0.96

    expandedWidth: parent.width
    expandedHeight: parent.height
    expandedRadius: 16
    expandedScale: 1.0

    Column {
        anchors.fill: parent
        // Expanded content
    }
}
```

The surface interpolates one normalized `progress` value. Position, size, radius and scale are derived from that value, so they stay synchronized. The animation can be retargeted when `expanded` changes while a transition is running.

For non-centered layouts, provide `collapsedX`, `collapsedY`, `expandedX` and `expandedY`. Their defaults center each geometry in the parent.

## Important: cross-window continuity

A `PanelWindow` is a separate Wayland surface. Two different `PanelWindow` instances cannot become the same QML item merely by animating their properties. `MorphSurface` guarantees a coordinated morph only within one QQuickWindow.

For a bar module that expands into a separate panel, use a shared overlay/host surface or a temporary visual carrier:
1. Measure the source item in screen coordinates with `mapToItem` / `mapToGlobal` as appropriate for the Quickshell version.
2. Render or clone the source appearance inside the overlay host.
3. Animate that carrier from the source rectangle to the destination rectangle, including radius and clipping.
4. Reveal the destination content as the carrier reaches its target.
5. Hide the source representation only after the handoff is complete.
6. Reverse the same sequence on close, and retarget from the current interpolated geometry if the user interrupts the transition.

Do not claim a true shared-element morph if the source and destination are still independently visible windows. A visual carrier is the bridge between those surfaces.

## Adding motion to a new module

Start by deciding which interaction states the module needs. A common pattern is `idle`, `hover`, `expanded` and `closing`. Keep the state semantic; do not encode animation progress into a pile of booleans.

For a simple hoverable module, use `BarCard`. For a compact-to-expanded surface in one window, use `MorphSurface`. For a panel opened from a bar module, integrate it with the shared overlay carrier rather than creating an unrelated slide animation.

Keep content transitions separate from geometry transitions. Geometry should establish the new surface first; content can then fade, clip or stagger into place. Prefer `Motion` tokens and shared curves over per-widget magic numbers.

## Design references

The implementation takes inspiration from Caelestia's fluid visual language, HakuSpace's coordinated surface and navigation transitions, and Serpantinum's shared-host approach. These are design references, not a requirement to duplicate their source code. Check each upstream project's license before copying implementation code.


## One progress value per transition

When a component has several animated properties that describe one visual state, prefer one normalized progress value and derive the properties from it. This keeps geometry and content phase-locked and makes an interrupted transition retarget cleanly.

The clipboard surface uses this pattern:

```qml
property real revealProgress: 0

Behavior on revealProgress {
    NumberAnimation {
        duration: root.closing
            ? Motion.surfaceCloseDuration
            : Motion.surfaceOpenDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: root.closing
            ? Motion.surfaceCloseCurve
            : Motion.surfaceOpenCurve
    }
}

Item {
    height: root.height * root.revealProgress
    y: root.height * (1 - root.revealProgress)
    opacity: root.revealProgress
}
```

Use this for a single surface transition. Do not force unrelated interactions (for example, a list item's hover state and a panel's open state) into the same progress value.

Notification cards use one progress for opacity, scale and vertical offset. Tray menus use one progress for reveal height, scale and opacity. BarCard.emphasisScale lets a module express selection emphasis without replacing the shared hover behavior.