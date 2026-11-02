import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "."

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 9

    Text {
        text: "↓"
        color: root.cPrimary
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        text: Services.SystemMonitorService.connected
            ? Services.SystemMonitorService.formatSpeed(
                  Services.SystemMonitorService.data.network_down_kib_s
              )
            : "--"
        color: root.cOnSurface
        font.pixelSize: 11
        font.bold: true
    }

    Text {
        text: "↑"
        color: root.cPrimary
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        text: Services.SystemMonitorService.connected
            ? Services.SystemMonitorService.formatSpeed(
                  Services.SystemMonitorService.data.network_up_kib_s
              )
            : "--"
        color: root.cOnSurface
        font.pixelSize: 11
        font.bold: true
    }
}
