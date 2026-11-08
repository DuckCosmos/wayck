import QtQuick
import QtQuick.Layouts
import "../"

Item {
    id: root
    required property var notification

    property int cornerRadius: 12
    property int horizontalPadding: 12
    property int topPadding: 10
    property int bottomPadding: 12
    property int contentSpacing: 12
    property bool exiting: false
    property real enterOffset: 12

    implicitWidth: 280
    implicitHeight: Math.max(76, textColumn.implicitHeight + topPadding + bottomPadding)
    width: implicitWidth
    height: implicitHeight
    opacity: 0
    scale: Motion.entranceScale

    transform: Translate { y: root.enterOffset }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.darker(Theme.surfaceContainer, 1.75)
        antialiasing: true
    }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.cornerRadius
        border.width: 1
        border.color: Qt.darker(Theme.outline, 1.15)
        antialiasing: true
    }

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.layoutDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.layoutCurve
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.topMargin: root.topPadding
        anchors.bottomMargin: root.bottomPadding
        spacing: root.contentSpacing

        Image {
            source: root.notification.image ? root.notification.image : root.notification.appIcon
            Layout.preferredWidth: 30
            Layout.preferredHeight: 30
            Layout.alignment: Qt.AlignVCenter
            fillMode: Image.PreserveAspectFit
            asynchronous: true
        }

        ColumnLayout {
            id: textColumn
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            spacing: 5

            Text {
                text: root.notification.summary
                font.pixelSize: 15
                font.bold: true
                color: Theme.primary
                Layout.fillWidth: true
                maximumLineCount: 2
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }

            Text {
                text: root.notification.body
                font.pixelSize: 12
                color: Theme.onSurface
                Layout.fillWidth: true
                maximumLineCount: 3
                wrapMode: Text.Wrap
                elide: Text.ElideRight
            }
        }
    }

    ParallelAnimation {
        id: enterAnimation
        NumberAnimation {
            target: root
            property: "opacity"
            to: 1
            duration: Motion.medium
            easing.type: Motion.standard
        }
        NumberAnimation {
            target: root
            property: "enterOffset"
            to: 0
            duration: Motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.surfaceOpenCurve
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: 1
            duration: Motion.slow
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.surfaceOpenCurve
        }
    }

    ParallelAnimation {
        id: exitAnimation
        NumberAnimation {
            target: root
            property: "opacity"
            to: 0
            duration: Motion.fast
            easing.type: Motion.standardIn
        }
        NumberAnimation {
            target: root
            property: "enterOffset"
            to: -10
            duration: Motion.normal
            easing.type: Motion.standardIn
        }
        NumberAnimation {
            target: root
            property: "scale"
            to: Motion.exitScale
            duration: Motion.normal
            easing.type: Motion.standardIn
        }
        onFinished: SysNotif.removeNotification(root.notification.id)
    }

    function dismiss(): void {
        if (exiting)
            return
        exiting = true
        exitAnimation.start()
    }

    HoverHandler { id: hoverHandler }

    Timer {
        interval: 5000
        running: !root.exiting && !hoverHandler.hovered
        repeat: false
        onTriggered: root.dismiss()
    }

    Component.onCompleted: Qt.callLater(() => enterAnimation.start())
}