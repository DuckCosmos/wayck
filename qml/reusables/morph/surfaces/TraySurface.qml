import QtQuick
import "../../../"
import "../../../bar/faces/tray"

MorphSurface {
    id: expandedRoot

    morphWidthMode: "content"
    morphMinWidth: 240
    morphPreferredWidth: 256
    morphWidthMargin: 24

    morphHeightMode: "content"
    morphMinHeight: 72
    morphPreferredHeight: 72
    morphHeightMargin: 24

    morphCollapsedRadius: 7
    morphExpandedRadius: 14
    morphSourceHoverEnabled: false
    morphRetargetable: true

    property var menu: (morph ? morph.surfaceData : null)

    signal closeRequested()

    implicitWidth: menuCard.implicitWidth
    implicitHeight: menuCard.implicitHeight

    TrayMenu {
        id: menuCard

        anchors.left: parent.left
        anchors.top: parent.top

        menu: expandedRoot.menu

        onCloseRequested: morph.close()
    }

    onCloseRequested: morph.close()
}
