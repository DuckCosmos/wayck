
import QtQuick
import QtQuick.Layouts
import "../../../"

Item {
    id: root

    signal updateRequested()
    signal closeRequested()

    property real holdProgress: 0
    property bool holdActive: false
    property bool completed: false
    property real wavePhase: 0

    implicitWidth: 340
    implicitHeight: 204

    Rectangle {
        anchors.fill: parent
        radius: 17
        color: Qt.alpha(Theme.surfaceContainer, 0.98)
        border.width: 1
        border.color: Theme.outline
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            spacing: 9

            Rectangle {
                Layout.preferredWidth: 38
                Layout.preferredHeight: 38
                radius: 12
                color: Qt.alpha(Theme.primary, 0.16)

                Text {
                    anchors.centerIn: parent
                    text: "󰇚"
                    color: Theme.primary
                    font.pixelSize: 20
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: I18n.t("updater.title")
                    color: Theme.surfaceForeground
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 0.6
                }

                Text {
                    Layout.fillWidth: true
                    text: UpdateController.localVersion + "  →  " + UpdateController.remoteVersion
                    color: Theme.outline
                    font.pixelSize: 10
                    elide: Text.ElideRight
                }
            }

            Text {
                text: "×"
                color: Theme.outline
                font.pixelSize: 20

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -7
                    onClicked: root.closeRequested()
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }

        Text {
            Layout.fillWidth: true
            text: I18n.t("updater.description")
            color: Theme.surfaceForeground
            opacity: 0.78
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }

        Item { Layout.fillHeight: true }

        Rectangle {
            id: holdButton
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            radius: 12
            color: Qt.darker(Theme.surfaceContainer, 1.28)
            border.width: 1
            border.color: root.holdActive ? Theme.primary : Theme.outline
            clip: true

            // The shader draws the fluid and its optional 3D bevel in one pass.
            WaveFill {
                anchors.fill: parent
                z: 0

                radius: parent.radius
                threeDimensional: 1.0
                fillLevel: root.holdProgress

                waveAmp: root.holdProgress > 0.001
                    && root.holdProgress < 0.99
                    ? 40 * Math.sin(root.holdProgress * Math.PI)
                    : 0

                phase: root.wavePhase

                color1: Qt.darker(Theme.primary, 1.08)
                color2: Theme.primary

                visible: root.holdProgress > 0.001
            }

            Text {
                anchors.centerIn: parent
                text: root.completed
                    ? I18n.t("updater.installing")
                    : (root.holdActive
                        ? I18n.t("updater.holding", { progress: Math.round(root.holdProgress * 100) })
                        : I18n.t("updater.hold"))
                color: root.holdProgress > 0.48 ? Theme.onPrimary : Theme.surfaceForeground
                font.pixelSize: 11
                font.bold: true
            }

            MouseArea {
                anchors.fill: parent
                enabled: !root.completed

                onPressed: {
                    root.holdActive = true
                    holdAnimation.restart()
                    SoundController.play("longCharge")
                }

                onReleased: {
                    root.holdActive = false
                    SoundController.stop("longCharge")

                    if (!root.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                onCanceled: {
                    root.holdActive = false
                    SoundController.stop("longCharge")

                    if (!root.completed) {
                        holdAnimation.stop()
                        drainAnimation.restart()
                    }
                }

                cursorShape: Qt.PointingHandCursor
            }
        }

        Text {
            Layout.fillWidth: true
            text: root.holdActive
                ? I18n.t("updater.cancelHint")
                : I18n.t("updater.installHint")
            color: Theme.outline
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true

            text: I18n.t("updater.changelog") + " ↗"
            color: Theme.primary
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor

                onClicked: {
                    const parts = String(UpdateController.localVersion)
                        .split(".")
                        .map(Number)

                    parts[parts.length - 1]++

                    const version = parts.join("")

                    Qt.openUrlExternally(
                        "https://github.com/DuckCosmos/wayck/blob/main/CHANGELOG.md#" + version
                    )
                }
            }
        }
    }

    NumberAnimation {
        id: holdAnimation
        target: root
        property: "holdProgress"
        from: 0
        to: 1
        duration: 3904
        easing.type: Easing.Linear

        onFinished: {
            if (!root.holdActive || root.completed)
                return

            root.completed = true
            root.updateRequested()
            SoundController.stop("longCharge")
        }
    }

    NumberAnimation {
        id: drainAnimation
        target: root
        property: "holdProgress"
        to: 0
        duration: Math.max(100, root.holdProgress * 210)
        easing.type: Easing.OutCubic
    }

    NumberAnimation on wavePhase {
        running: root.holdProgress > 0.0
            && root.holdProgress < 1.0

        from: 0
        to: Math.PI * 2

        duration: 600
        loops: Animation.Infinite
    }
}
