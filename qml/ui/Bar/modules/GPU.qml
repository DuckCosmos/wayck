import QtQuick
import QtQuick.Layouts
import "../../../services" as Services
import "."

BarCard {
    id: root

    readonly property real metricValue:
        Number(Services.SystemMonitorService.data.gpu_percent) || 0

    implicitHeight: 36
    horizontalPadding: 8

    Text {
        text: "G"
        color: root.cPrimary
        font.pixelSize: 12
        font.bold: true
        Layout.alignment: Qt.AlignVCenter
    }

    Item {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24

        Canvas {
            id: ring

            anchors.fill: parent
            antialiasing: true

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const cx = width / 2
                const cy = height / 2
                const radius = Math.min(width, height) / 2 - 2
                const amount = Math.max(
                    0,
                    Math.min(100, root.metricValue)
                ) / 100

                // Anel de fundo.
                ctx.beginPath()
                ctx.arc(cx, cy, radius, 0, Math.PI * 2)
                ctx.lineWidth = 2.4
                ctx.strokeStyle = root.cOutline
                ctx.globalAlpha = 0.38
                ctx.stroke()

                // Progresso.
                if (amount > 0) {
                    ctx.beginPath()
                    ctx.arc(
                        cx,
                        cy,
                        radius,
                        -Math.PI / 2,
                        -Math.PI / 2 + amount * Math.PI * 2
                    )

                    ctx.lineWidth = 2.4
                    ctx.lineCap = "round"
                    ctx.strokeStyle = root.cPrimary
                    ctx.globalAlpha = 1
                    ctx.stroke()
                }

                ctx.globalAlpha = 1
            }

            Connections {
                target: root

                function onMetricValueChanged() {
                    ring.requestPaint()
                }

                function onCPrimaryChanged() {
                    ring.requestPaint()
                }

                function onCOutlineChanged() {
                    ring.requestPaint()
                }
            }

            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.centerIn: parent

            text: "▣"
            color: root.cOnSurface

            font.pixelSize: 11
            font.bold: true
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter

        text: {
            const monitor = Services.SystemMonitorService

            if (!monitor.connected)
                return "--"

            if (!monitor.data.gpu_available ||
                monitor.data.gpu_percent === null)
                return "N/A"

            return Math.round(root.metricValue) + "%"
        }
        color: root.cOnSurface

        font.pixelSize: 12
        font.bold: true
    }
}
