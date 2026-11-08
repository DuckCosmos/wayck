import QtQuick
import Quickshell
import ".."

PanelWindow {
    id: root
    property bool hasNotifications: SysNotif.notifications.length > 0

    anchors { top: true; left: true; right: true }
    margins { top: 43 }

    visible: hasNotifications || hideTimer.running
    implicitWidth: 420
    implicitHeight: content.implicitHeight
    exclusiveZone: -1
    color: "transparent"

    onHasNotificationsChanged: {
        if (hasNotifications)
            hideTimer.stop()
        else
            hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: Motion.surfaceCloseDuration
        repeat: false
    }

    Column {
        id: content
        width: 280
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Motion.stackDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.layoutCurve
            }
        }

        Repeater {
            model: ScriptModel {
                objectProp: "id"
                values: SysNotif.notifications.slice().reverse()
            }

            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                width: content.width
                height: implicitHeight
            }
        }
    }
}