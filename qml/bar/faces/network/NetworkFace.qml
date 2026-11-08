import QtQuick
import QtQuick.Layouts
import "../../../"

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
        text: SysData.connected
            ? SysData.formatSpeed(
                  SysData.data.network_down_kib_s
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
        text: SysData.connected
            ? SysData.formatSpeed(
                  SysData.data.network_up_kib_s
              )
            : "--"
        color: Theme.onSurface
        font.pixelSize: 11
        font.bold: true
    }
}
