import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "."
import "../../../core"

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 9

    Text {
        text: "↓"
        color: Theme.primary
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        text: Services.SystemMonitorService.connected
            ? Services.SystemMonitorService.formatSpeed(
                  Services.SystemMonitorService.data.network_down_kib_s
              )
            : "--"
        color: Theme.onSurface
        font.pixelSize: 11
        font.bold: true
    }

    Text {
        text: "↑"
        color: Theme.primary
        font.pixelSize: 14
        font.bold: true
    }

    Text {
        text: Services.SystemMonitorService.connected
            ? Services.SystemMonitorService.formatSpeed(
                  Services.SystemMonitorService.data.network_up_kib_s
              )
            : "--"
        color: Theme.onSurface
        font.pixelSize: 11
        font.bold: true
    }
}
