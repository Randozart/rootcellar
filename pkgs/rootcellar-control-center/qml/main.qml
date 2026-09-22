import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    visible: true
    width: 960
    height: 640
    title: "RootCellar Control Center"
    color: "#191622"

    // Backend context properties are set in Python before engine.load()
    // cellarBackend, flakeBackend, rebuildBackend, serviceBackend

    header: ToolBar {
        RowLayout {
            anchors.fill: parent

            Label {
                text: "RootCellar"
                font.bold: true
                font.pixelSize: 16
                color: "#cdd6f4"
            }

            Item { Layout.fillWidth: true }

            Label {
                id: statusLabel
                text: ""
                color: "#a6adc8"
                font.pixelSize: 12
            }
        }
    }

    TabBar {
        id: tabBar
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        currentIndex: 0

        background: Rectangle {
            color: "#1e1e2e"
        }

        TabButton {
            text: "Packages"
            font.pixelSize: 13
            contentItem: Label {
                text: parent.text
                font: parent.font
                color: tabBar.currentIndex === 0 ? "#cdd6f4" : "#a6adc8"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: tabBar.currentIndex === 0 ? "#313244" : "transparent"
            }
        }
        TabButton {
            text: "Flake"
            font.pixelSize: 13
            contentItem: Label {
                text: parent.text
                font: parent.font
                color: tabBar.currentIndex === 1 ? "#cdd6f4" : "#a6adc8"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: tabBar.currentIndex === 1 ? "#313244" : "transparent"
            }
        }
        TabButton {
            text: "Rebuild"
            font.pixelSize: 13
            contentItem: Label {
                text: parent.text
                font: parent.font
                color: tabBar.currentIndex === 2 ? "#cdd6f4" : "#a6adc8"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: tabBar.currentIndex === 2 ? "#313244" : "transparent"
            }
        }
        TabButton {
            text: "Settings"
            font.pixelSize: 13
            contentItem: Label {
                text: parent.text
                font: parent.font
                color: tabBar.currentIndex === 3 ? "#cdd6f4" : "#a6adc8"
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                color: tabBar.currentIndex === 3 ? "#313244" : "transparent"
            }
        }
    }

    StackLayout {
        anchors.top: tabBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        currentIndex: tabBar.currentIndex

        PackagesPage {
            cellarBackend: root.cellarBackend
        }
        FlakePage {
            flakeBackend: root.flakeBackend
        }
        RebuildPage {
            rebuildBackend: root.rebuildBackend
            serviceBackend: root.serviceBackend
        }
        SettingsPage {
            cellarBackend: root.cellarBackend
        }
    }

    // Toast notifications
    Timer {
        id: toastTimer
        interval: 3000
        onTriggered: toastLabel.visible = false
    }

    Label {
        id: toastLabel
        visible: false
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.margins: 16
        padding: 12
        background: Rectangle {
            radius: 8
            color: "#313244"
            border.color: "#45475a"
        }
        color: "#cdd6f4"
    }

    function showToast(message: string, isError: bool) {
        toastLabel.text = message
        toastLabel.color = isError ? "#f38ba8" : "#a6e3a1"
        toastLabel.visible = true
        toastTimer.restart()
    }
}
