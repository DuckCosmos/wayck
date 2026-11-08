import QtQuick
import "../../../"
import "."

Item {
    id: root

    required property var menu

    signal closeRequested()

    implicitWidth: menuCard.implicitWidth
    implicitHeight: menuCard.implicitHeight

    TrayMenu {
        id: menuCard

        anchors.left: parent.left
        anchors.top: parent.top

        menu: root.menu
        onCloseRequested: root.closeRequested()
    }
}
