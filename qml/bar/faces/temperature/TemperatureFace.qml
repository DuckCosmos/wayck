import QtQuick
import QtQuick.Layouts
import "../../../"

BarCard {
    id: root

    implicitHeight: 36
    horizontalPadding: 9

    Text {
        text: "♨"
        color: Theme.primary
        font.pixelSize: 15
    }

    Text {
        text: {
            const monitor = SysData

            if (!monitor.connected)
                return "--°C"

            const temperature = monitor.data.temperature_c

            return temperature !== null && temperature !== undefined
                ? Math.round(temperature) + "°C"
                : I18n.t("common.na")
        }

        color: Theme.surfaceForeground
        font.pixelSize: 12
        font.bold: true
    }
}
