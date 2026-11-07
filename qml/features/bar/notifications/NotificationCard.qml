import QtQuick
import QtQuick.Layouts
import "../bar/modules"

BarCard {
    id: root

    required property var notification

    Text {
        text: root.notification.summary
        implicitWidth: 30
    }

    signal dismissRequested()
}