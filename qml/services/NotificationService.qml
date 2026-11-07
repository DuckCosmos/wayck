pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

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

        notification.original.dismiss()

        root.notifications = root.notifications.filter(n => n.id !== id)

        console.log("[NotificationService] removed:", id)
    }

    Connections {
        target: serverNot

        function onNotification(notification) {
            notification.tracked = true

            root.notifications = [
                {
                    id: notification.id,
                    summary: notification.summary,
                    body: notification.body,
                    appName: notification.appName,
                    appIcon: notification.appIcon,
                    image: notification.image,
                    urgency: notification.urgency,
                    timestamp: new Date(),
                    original: notification
                },
                ...root.notifications
            ]

            console.log("[NotificationService] history:", root.notifications.length)
        }
    }
    
}