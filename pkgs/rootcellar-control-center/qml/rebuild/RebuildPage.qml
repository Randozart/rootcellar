import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: page
    property var rebuildBackend: null
    property var serviceBackend: null

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 12

        Label {
            text: "Rebuild"
            font.bold: true
            font.pixelSize: 16
            color: "#cdd6f4"
        }

        Item { Layout.fillWidth: true }

        Button {
            text: "Compute Diff"
            onClicked: if (rebuildBackend) rebuildBackend.computeDiff()
            font.pixelSize: 12
        }
        Button {
            text: "Deploy"
            highlighted: true
            onClicked: if (rebuildBackend) rebuildBackend.deploy()
            font.pixelSize: 12
        }
    }

    // Progress bar
    ColumnLayout {
        Layout.fillWidth: true
        Layout.margins: 8
        spacing: 4
        visible: progressBar.value > 0

        RowLayout {
            Label {
                id: progressLabel
                text: ""
                font.pixelSize: 12
                color: "#a6adc8"
            }
            Item { Layout.fillWidth: true }
            Label {
                id: progressPct
                text: ""
                font.pixelSize: 11
                color: "#6c7086"
            }
        }

        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            value: 0
            background: Rectangle {
                implicitHeight: 8
                radius: 4
                color: "#313244"
            }
            contentItem: Item {
                implicitHeight: 8
                Rectangle {
                    y: 0
                    width: progressBar.visualPosition * parent.width
                    height: parent.height
                    radius: 4
                    color: "#a06be0"
                }
            }
        }
    }

    // Diff view
    Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 8
        color: "#181825"
        radius: 8

        ScrollView {
            anchors.fill: parent
            anchors.margins: 8

            TextArea {
                id: diffView
                readOnly: true
                color: "#cdd6f4"
                font.family: "monospace"
                font.pixelSize: 12
                background: Rectangle { color: "transparent" }
                placeholderText: "Click 'Compute Diff' to see what would change"
            }
        }
    }

    // Service reload panel
    Rectangle {
        Layout.fillWidth: true
        Layout.margins: 8
        height: serviceColumn.implicitHeight + 24
        color: "#1e1e2e"
        radius: 8
        visible: serviceModel.count > 0

        ColumnLayout {
            id: serviceColumn
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Label {
                text: "Reload Services"
                font.bold: true
                font.pixelSize: 13
                color: "#cdd6f4"
            }

            Repeater {
                model: ListModel { id: serviceModel }

                RowLayout {
                    spacing: 8

                    Label {
                        text: model.displayName
                        font.pixelSize: 12
                        color: "#a6adc8"
                        Layout.fillWidth: true
                    }

                    Switch {
                        checked: model.canAutoReload
                        onToggled: {
                            // Update auto-reload preference
                        }
                    }

                    Button {
                        text: "Reload"
                        onClicked: if (serviceBackend) serviceBackend.reload(model.name)
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (serviceBackend) serviceBackend.listRunning()
    }

    Connections {
        target: rebuildBackend
        function onProgressUpdated(pct, msg) {
            progressBar.value = pct / 100
            progressLabel.text = msg
            progressPct.text = pct + "%"
        }
        function onDiffReady(diff) {
            diffView.text = diff
        }
        function onRebuildFinished(ok, msg) {
            root.showToast(msg, !ok)
            progressBar.value = ok ? 1 : 0
            if (ok) {
                progressLabel.text = "Complete"
                if (serviceBackend) serviceBackend.listRunning()
            }
        }
        function onBuildLogLine(line) {
            diffView.append(line)
        }
    }

    Connections {
        target: serviceBackend
        function onServicesReady(json) {
            serviceModel.clear()
            try {
                var services = JSON.parse(json)
                for (var i = 0; i < services.length; i++) {
                    serviceModel.append(services[i])
                }
            } catch(e) {}
        }
        function onReloadFinished(ok, msg) {
            root.showToast(msg, !ok)
        }
    }
}
