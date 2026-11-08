import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        top: 43
    }

    visible: SysNotif.notifications.length > 0
    implicitWidth: 420
    implicitHeight: content.implicitHeight
    exclusiveZone: -1

    color: "transparent"

    ColumnLayout {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Repeater {
            model: ScriptModel {
                objectProp: "id"
                values: SysNotif.notifications.slice().reverse()
            }

            delegate: NotificationCard {
                required property var modelData

                notification: modelData

                Layout.fillWidth: true
            }
        }
    }
}