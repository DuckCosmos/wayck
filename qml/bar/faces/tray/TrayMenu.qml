import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../"
import "."

BarCard {
    id: root

    required property var menu

    signal closeRequested()
    signal pointerEntered()
    signal pointerExited()

    property var activeMenu: menu
    property bool menuVisible: false

    property var menuStack: []

    readonly property int menuWidth: 240
    readonly property int entryHeight: 34

    horizontalPadding: 8
    verticalPadding: 8
    showBackground: true
    showBorder: true

    implicitWidth: menuWidth + horizontalPadding * 2
    implicitHeight: menuColumn.implicitHeight + verticalPadding * 2

    width: implicitWidth
    height: menuVisible ? implicitHeight : 0
    clip: true

    Behavior on height {
        NumberAnimation {
            duration: root.menuVisible ? Motion.surfaceOpenDuration : Motion.surfaceCloseDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.menuVisible ? Motion.surfaceOpenCurve : Motion.surfaceCloseCurve
        }
    }

    onMenuChanged: {
        activeMenu = menu
        menuStack = []
    }

    // Idiomas RTL (árabe, persa): espelha o menu.
    LayoutMirroring.enabled: I18n.rtl
    LayoutMirroring.childrenInherit: true

    scale: menuVisible ? 1 : Motion.subtleScale
    transformOrigin: Item.Bottom

    Behavior on scale {
        NumberAnimation {
            duration: Motion.surfaceOpenDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.morphCurve
        }
    }

    opacity: menuVisible ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.contentFadeDuration
            easing.type: Motion.standardInOut
        }
    }

    QsMenuOpener {
        id: opener
        menu: root.activeMenu
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered)
                root.pointerEntered()
            else
                root.pointerExited()
        }
    }

    Column {
        id: menuColumn

        width: root.menuWidth
        spacing: 4

        move: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Motion.menuContentDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.layoutCurve
            }
        }

        add: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Motion.menuContentDuration
                easing.type: Motion.standard
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "opacity"
                to: 0
                duration: Motion.fast
                easing.type: Motion.standardIn
            }
        }

        Item {
            width: parent.width
            height: 30

            visible: root.menuStack.length > 0

            Rectangle {
                anchors.fill: parent
                radius: 6

                color: backMouse.containsMouse
                    ? Qt.darker(Theme.surfaceContainer, 1.12)
                    : "transparent"
            }

            Text {
                anchors.fill: parent

                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignLeft

                leftPadding: 10

                text: "‹  " + I18n.t("tray.back")

                color: Theme.onSurface
                font.pixelSize: 13
            }

            MouseArea {
                id: backMouse

                anchors.fill: parent

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                onClicked: {
                    const stack = root.menuStack.slice()

                    root.activeMenu = stack.pop()
                    root.menuStack = stack
                }
            }
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: entryItem

                required property var modelData

                width: menuColumn.width

                height: modelData.isSeparator
                    ? 9
                    : root.entryHeight

                property bool hovered: false

                Rectangle {
                    anchors.fill: parent
                    radius: 6

                    color: entryItem.hovered
                        ? Qt.darker(Theme.surfaceContainer, 1.12)
                        : "transparent"

                    visible: !entryItem.modelData.isSeparator
                }

                Rectangle {
                    anchors.centerIn: parent

                    width: parent.width - 16
                    height: 1

                    color: Theme.outline

                    visible: entryItem.modelData.isSeparator
                }

                Image {
                    id: entryIcon

                    anchors.left: parent.left
                    anchors.leftMargin: 9
                    anchors.verticalCenter: parent.verticalCenter

                    width: 16
                    height: 16

                    source: entryItem.modelData.icon
                    fillMode: Image.PreserveAspectFit

                    visible: !entryItem.modelData.isSeparator
                        && source !== ""
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: entryIcon.visible ? 32 : 10

                    anchors.right: arrow.left
                    anchors.rightMargin: 8

                    anchors.verticalCenter: parent.verticalCenter

                    text: entryItem.modelData.text

                    color: Theme.onSurface
                    opacity: entryItem.modelData.enabled ? 1 : 0.45

                    font.pixelSize: 13
                    elide: Text.ElideRight

                    visible: !entryItem.modelData.isSeparator
                }

                Text {
                    id: arrow

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    text: entryItem.modelData.hasChildren ? "›" : ""

                    color: Theme.onSurface
                    font.pixelSize: 18

                    visible: !entryItem.modelData.isSeparator
                }

                MouseArea {
                    anchors.fill: parent

                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton

                    enabled: !entryItem.modelData.isSeparator
                        && entryItem.modelData.enabled

                    onEntered: entryItem.hovered = true
                    onExited: entryItem.hovered = false

                    onClicked: {
                        const entry = entryItem.modelData

                        if (entry.hasChildren) {
                            root.menuStack = root.menuStack.concat([
                                root.activeMenu
                            ])

                            root.activeMenu = entry
                            return
                        }

                        entry.triggered()
                        root.closeRequested()
                    }
                }
            }
        }
    }
}