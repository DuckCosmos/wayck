import QtQuick
import QtQuick.Layouts
import "../../../"

BarCard {
    id: root

    property var now: new Date()
    implicitHeight: 36
    horizontalPadding: 10

    Text {
        text: Qt.formatDateTime(root.now, "HH:mm:ss")
        color: Theme.surfaceForeground
        font.pixelSize: 14
        font.bold: true
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        color: Theme.outline
        opacity: 0.7
    }

    Text {
        text: Qt.formatDateTime(root.now, I18n.t("clock.dateFormat", "dd/MM/yy"))
        color: Theme.surfaceForeground
        font.pixelSize: 11
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
