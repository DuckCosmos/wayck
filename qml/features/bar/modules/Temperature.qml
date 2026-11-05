import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "."

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 9

    Text {
        text: "♨"
        color: root.cPrimary
        font.pixelSize: 15
    }

    Text {
        text: {
            const monitor = Services.SystemMonitorService

            if (!monitor.connected)
                return "--°C"

            const temperature = monitor.data.temperature_c

            return temperature !== null && temperature !== undefined
                ? Math.round(temperature) + "°C"
                : "N/A"
        }

        color: root.cOnSurface
        font.pixelSize: 12
        font.bold: true
    }
}
