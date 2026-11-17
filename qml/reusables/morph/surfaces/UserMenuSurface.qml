import QtQuick
import QtQuick.Layouts
import "../../../"
MorphSurface {
    id: expandedRoot

    morphMinWidth: 300
    morphMaxWidth: 360
    morphWidthMargin: 32
    morphHeightMode: "content"
    morphMinHeight: 280
    morphPreferredHeight: 500
    morphHeightMargin: 32
    morphHeightAvailableFloor: 300

    property string page: "home"

    // The Face can request the Power tab when opening this surface.
    onMorphChanged: {
        const requestedPage = morph && morph.surfaceData
            ? morph.surfaceData.page
            : ""

        if (requestedPage === "home" || requestedPage === "power")
            page = requestedPage
    }

    readonly property var settingsItems: [
        { id: "hyprland", symbol: "H" },
        { id: "displays", symbol: "▣" },
        { id: "network", symbol: "⌁" },
        { id: "audio", symbol: "♫" },
        { id: "bluetooth", symbol: "ᛒ" },
        { id: "appearance", symbol: "◈" },
        { id: "system", symbol: "⚙" },
        { id: "monitor", symbol: "▥" }
    ]

    readonly property var powerItems: [
        { id: "lock", symbol: "▣" },
        { id: "suspend", symbol: "☾" },
        { id: "reboot", symbol: "↻" },
        { id: "poweroff", symbol: "⏻" }
    ]

    readonly property var confirmActions: [
        "suspend",
        "reboot",
        "poweroff"
    ]

    implicitWidth: 360

    implicitHeight: page === "home"
        ? 500
        : page === "power"
            ? 410
            : 280

    LayoutMirroring.enabled: I18n.rtl
    LayoutMirroring.childrenInherit: true

    function actionTitle(action): string {
        return confirmActions.includes(action)
            ? I18n.t("usermenu.confirm." + action + ".title")
            : I18n.t("usermenu.confirm.default.title")
    }

    function actionDescription(action): string {
        return confirmActions.includes(action)
            ? I18n.t("usermenu.confirm." + action + ".description")
            : ""
    }

    Rectangle {
        anchors.fill: parent

        radius: 18
        color: Theme.surfaceContainer

        border.width: 1
        border.color: Qt.darker(Theme.outline, 1.15)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 10

            RowLayout {
                Layout.fillWidth: true
                spacing: 11

                Rectangle {
                    Layout.preferredWidth: 46
                    Layout.preferredHeight: 46

                    radius: 15
                    color: Theme.primary

                    Text {
                        anchors.centerIn: parent

                        text: UserController.username.length > 0
                            ? UserController.username
                                .substring(0, 1).toUpperCase()
                            : "?"

                        color: Theme.onPrimary
                        font.pixelSize: 23
                        font.bold: true
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    Text {
                        text: UserController.username
                        color: Theme.surfaceForeground
                        font.pixelSize: 16
                        font.bold: true
                    }

                    Text {
                        Layout.fillWidth: true

                        text: UserController.hostname
                            + "  ·  " + UserController.desktop

                        color: Theme.outline
                        font.pixelSize: 10
                        elide: Text.ElideRight
                    }
                }

                Text {
                    text: "WAYCK"
                    color: Theme.primary
                    font.pixelSize: 10
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 0

                visible: expandedRoot.page !== "confirm"

                Item {
                    id: tabs

                    Layout.fillWidth: true
                    Layout.preferredHeight: 34

                    Rectangle {
                        anchors.fill: parent
                        radius: 9
                        color: Qt.darker(Theme.surfaceContainer, 1.08)
                    }

                    Rectangle {
                        id: indicator

                        width: tabs.width / 2
                        height: tabs.height

                        radius: 9
                        color: Theme.primary

                        x: expandedRoot.page === "power"
                            ? (I18n.rtl ? 0 : width)
                            : (I18n.rtl ? width : 0)

                        Behavior on x {
                            NumberAnimation {
                                duration: 250
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("usermenu.tabs.control")

                                color: expandedRoot.page === "home"
                                    ? Theme.onPrimary
                                    : Theme.surfaceForeground

                                font.pixelSize: 12
                                font.bold: true

                                Behavior on color {
                                    ColorAnimation {
                                        duration: 400
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: expandedRoot.page = "home"
                                cursorShape: Qt.PointingHandCursor
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Text {
                                anchors.centerIn: parent
                                text: I18n.t("usermenu.tabs.power")

                                color: expandedRoot.page === "power"
                                    ? Theme.onPrimary
                                    : Theme.surfaceForeground

                                font.pixelSize: 12
                                font.bold: true
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: expandedRoot.page = "power"
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                visible: expandedRoot.page === "home"

                Text {
                    text: I18n.t("usermenu.sections.settings")
                    color: Theme.outline
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                }

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: expandedRoot.settingsItems

                        delegate: Rectangle {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 66

                            radius: 11

                            color: tileMouse.containsMouse
                                ? Qt.lighter(
                                    Theme.surfaceContainer,
                                    1.12
                                )
                                : Qt.darker(
                                    Theme.surfaceContainer,
                                    1.04
                                )

                            border.width: 1
                            border.color: Qt.darker(
                                Theme.outline,
                                1.25
                            )

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 9

                                Text {
                                    Layout.preferredWidth: 25

                                    text: modelData.symbol
                                    color: Theme.primary
                                    font.pixelSize: 20
                                    font.bold: true

                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true

                                        text: I18n.t(
                                            "usermenu.settings."
                                            + modelData.id + ".title"
                                        )

                                        color: Theme.surfaceForeground
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        text: I18n.t(
                                            "usermenu.settings."
                                            + modelData.id + ".subtitle"
                                        )

                                        color: Theme.outline
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: tileMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: {
                                    UserController.openSettings(
                                        modelData.id
                                    )

                                    morph.close()
                                }
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                visible: expandedRoot.page === "power"

                Text {
                    text: I18n.t("usermenu.sections.power")
                    color: Theme.outline
                    font.pixelSize: 10
                    font.bold: true
                    font.capitalization: Font.AllUppercase
                }

                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: 8
                    columnSpacing: 8

                    Repeater {
                        model: expandedRoot.powerItems

                        delegate: Rectangle {
                            id: powerTile

                            required property var modelData

                            property string action: modelData.id

                            // Estado individual deste botão.
                            property real holdProgress: 0
                            property real wavePhase: 0
                            property bool holdActive: false
                            property bool completed: false

                            Layout.fillWidth: true
                            Layout.preferredHeight: 66

                            radius: 11
                            clip: true

                            color: powerTileMouse.containsMouse
                                ? Qt.lighter(
                                    Theme.surfaceContainer,
                                    1.12
                                )
                                : Qt.darker(
                                    Theme.surfaceContainer,
                                    1.04
                                )

                            border.width: 1
                            border.color: Qt.darker(
                                Theme.outline,
                                1.25
                            )

                            WaveFill {
                                anchors.fill: parent
                                z: 0

                                radius: parent.radius
                                threeDimensional: 1.0

                                direction: 2

                                fillLevel: powerTile.holdProgress

                                waveAmp: powerTile.holdProgress > 0.001
                                    && powerTile.holdProgress < 0.99
                                    ? 40 * Math.sin(
                                        powerTile.holdProgress * Math.PI
                                    )
                                    : 0

                                phase: powerTile.wavePhase
                                use3D: true

                                color1: Qt.darker(Theme.primary, 1.08)
                                color2: Theme.primary

                                visible: powerTile.holdProgress > 0.001
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 9
                                spacing: 9

                                Text {
                                    Layout.preferredWidth: 25

                                    text: powerTile.modelData.symbol
                                    color: Theme.primary
                                    font.pixelSize: 19
                                    font.bold: true

                                    horizontalAlignment: Text.AlignHCenter
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 3

                                    Text {
                                        Layout.fillWidth: true

                                        text: I18n.t(
                                            "usermenu.power."
                                            + powerTile.action + ".title"
                                        )

                                        color: Theme.surfaceForeground
                                        font.pixelSize: 11
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        Layout.fillWidth: true

                                        text: I18n.t(
                                            "usermenu.power."
                                            + powerTile.action + ".subtitle"
                                        )

                                        color: Theme.outline
                                        font.pixelSize: 9
                                        elide: Text.ElideRight
                                    }
                                }
                            }

                            MouseArea {
                                id: powerTileMouse

                                anchors.fill: parent
                                enabled: !powerTile.completed

                                onPressed: {
                                    const longHold =
                                        powerTile.action === "poweroff"
                                        || powerTile.action === "reboot"

                                    drainAnimation.stop()
                                    powerTile.holdProgress = 0
                                    powerTile.holdActive = true

                                    holdAnimation.restart()

                                    SoundController.play(
                                        longHold
                                            ? "longCharge"
                                            : "shortCharge"
                                    )
                                }

                                onReleased: {
                                    powerTile.holdActive = false

                                    const longHold =
                                        powerTile.action === "poweroff"
                                        || powerTile.action === "reboot"

                                    SoundController.stop(
                                        longHold
                                            ? "longCharge"
                                            : "shortCharge"
                                    )

                                    if (!powerTile.completed) {
                                        holdAnimation.stop()
                                        drainAnimation.restart()
                                    }
                                }

                                onCanceled: {
                                    powerTile.holdActive = false

                                    const longHold =
                                        powerTile.action === "poweroff"
                                        || powerTile.action === "reboot"

                                    SoundController.stop(
                                        longHold
                                            ? "longCharge"
                                            : "shortCharge"
                                    )

                                    if (!powerTile.completed) {
                                        holdAnimation.stop()
                                        drainAnimation.restart()
                                    }
                                }

                                cursorShape: Qt.PointingHandCursor
                            }

                            NumberAnimation {
                                id: holdAnimation

                                target: powerTile
                                property: "holdProgress"

                                from: 0
                                to: 1

                                duration:
                                    powerTile.action === "poweroff"
                                    || powerTile.action === "reboot"
                                    ? 3904
                                    : 1535

                                easing.type: Easing.Linear

                                onFinished: {
                                    if (!powerTile.holdActive
                                            || powerTile.completed)
                                        return

                                    powerTile.completed = true

                                    UserController.executePower(
                                        powerTile.action
                                    )

                                    const longHold =
                                        powerTile.action === "poweroff"
                                        || powerTile.action === "reboot"

                                    SoundController.stop(
                                        longHold
                                            ? "longCharge"
                                            : "shortCharge"
                                    )
                                }
                            }

                            NumberAnimation {
                                id: drainAnimation

                                target: powerTile
                                property: "holdProgress"

                                to: 0

                                duration: Math.max(
                                    100,
                                    powerTile.holdProgress * 210
                                )

                                easing.type: Easing.OutCubic
                            }

                            NumberAnimation on wavePhase {
                                running: powerTile.holdProgress > 0.0
                                    && powerTile.holdProgress < 1.0

                                from: 0
                                to: Math.PI * 2

                                duration: 600
                                loops: Animation.Infinite
                            }
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
                visible: expandedRoot.page !== "confirm"
            }

            Text {
                visible: expandedRoot.page !== "confirm"
                Layout.fillWidth: true

                text: "Wayck "
                    + I18n.t("usermenu.footer")
                    + "  ·  Linux"

                color: Theme.outline
                font.pixelSize: 9

                horizontalAlignment: Text.AlignHCenter
            }
        }
    }
}
