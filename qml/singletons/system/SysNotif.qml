
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "../../"

Singleton {
    id: root

    NotificationServer {
        id: serverNot
    }

    property var notifications: []

    function removeNotification(id) {
        const notification = root.notifications.find(n => n.id === id)

        if (!notification)
            return

        root.notifications = root.notifications.filter(n => n.id !== id)

        try {
            if (notification.original && notification.original.tracked)
                notification.original.tracked = false
        } catch (error) {
            console.warn(
                "[SysNotif] original já fechado ou indisponível:",
                id,
                error
            )
        }

        console.log("[SysNotif] removed:", id)
    }

    Connections {
        target: serverNot

        function onNotification(notification) {
            notification.tracked = true
            SoundController.play("notification")

            const hints = notification.hints || {}
            const filePath = hints["wayck-file-path"] || ""

            root.notifications = [
                {
                    id: notification.id,
                    summary: notification.summary,
                    body: notification.body,
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    desktopEntry: notification.desktopEntry,
                    filePath: filePath,
                    image: notification.image,
                    urgency: notification.urgency,
                    timestamp: new Date(),
                    original: notification
                },
                ...root.notifications
            ]

            console.log(
                "[SysNotif] notification:",
                notification.appName,
                "desktopEntry:",
                notification.desktopEntry,
                "filePath:",
                filePath
            )

            console.log("[SysNotif] history:", root.notifications.length)
        }
    }
}
