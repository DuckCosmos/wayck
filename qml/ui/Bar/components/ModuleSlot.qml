import QtQuick

Item {
    id: root

    required property string moduleId
    property url sourceUrl: ""

    property color cPrimary: "#ffb59b"
    property color cOnPrimary: "#55200a"
    property color cSurfaceContainer: "#322824"
    property color cOnSurface: "#f1dfd9"
    property color cOutline: "#a08d86"

    implicitWidth: loader.implicitWidth
    implicitHeight: loader.implicitHeight
    width: implicitWidth
    height: implicitHeight

    function applyTheme(target) {
        if (!target)
            return

        if ("cPrimary" in target)
            target.cPrimary = Qt.binding(() => root.cPrimary)
        if ("cOnPrimary" in target)
            target.cOnPrimary = Qt.binding(() => root.cOnPrimary)
        if ("cSurfaceContainer" in target)
            target.cSurfaceContainer = Qt.binding(() => root.cSurfaceContainer)
        if ("cOnSurface" in target)
            target.cOnSurface = Qt.binding(() => root.cOnSurface)
        if ("cOutline" in target)
            target.cOutline = Qt.binding(() => root.cOutline)
    }

    Loader {
        id: loader
        source: root.sourceUrl
        
        onLoaded: {
            root.applyTheme(item)
            console.log(
                "[WAYCK DEBUG] MODULE LOADED:",
                root.moduleId,
                root.sourceUrl,
                "size:",
                loader.implicitWidth,
                loader.implicitHeight
            )
        }

        onStatusChanged: {
            console.log(
                "[WAYCK DEBUG] MODULE STATUS:",
                root.moduleId,
                loader.status,
                root.sourceUrl
            )

            if (loader.status === Loader.Error)
                console.warn("[WAYCK DEBUG] MODULE ERROR:", root.moduleId)
        }

    }
}
