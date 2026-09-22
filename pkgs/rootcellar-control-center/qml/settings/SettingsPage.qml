import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: page
    property var cellarBackend: null

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 12

        Label {
            text: "Settings"
            font.bold: true
            font.pixelSize: 16
            color: "#cdd6f4"
        }

        Item { Layout.fillWidth: true }

        Label {
            text: "Changes require deploy"
            font.pixelSize: 11
            color: "#f9e2af"
        }
    }

    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 8

        ColumnLayout {
            width: parent.width
            spacing: 16

            // Identity section
            GroupBox {
                title: "Identity"
                Layout.fillWidth: true
                font.pixelSize: 13

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Label { text: "Timezone:"; Layout.preferredWidth: 120; font.pixelSize: 12 }
                        TextField {
                            id: tzField
                            text: "Europe/Amsterdam"
                            Layout.fillWidth: true
                            color: "#cdd6f4"
                            background: Rectangle { radius: 4; color: "#313244" }
                        }
                    }
                    RowLayout {
                        Label { text: "Locale:"; Layout.preferredWidth: 120; font.pixelSize: 12 }
                        TextField {
                            id: localeField
                            text: "en_US.UTF-8"
                            Layout.fillWidth: true
                            color: "#cdd6f4"
                            background: Rectangle { radius: 4; color: "#313244" }
                        }
                    }
                    RowLayout {
                        Label { text: "Hostname:"; Layout.preferredWidth: 120; font.pixelSize: 12 }
                        TextField {
                            id: hostField
                            text: "cellar"
                            Layout.fillWidth: true
                            color: "#cdd6f4"
                            background: Rectangle { radius: 4; color: "#313244" }
                        }
                    }
                }
            }

            // Features section
            GroupBox {
                title: "Features"
                Layout.fillWidth: true
                font.pixelSize: 13

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 12

                    RowLayout {
                        Label { text: "Docker:"; Layout.fillWidth: true; font.pixelSize: 12 }
                        Switch { id: dockerToggle; checked: true }
                    }
                    RowLayout {
                        Label { text: "CUDA:"; Layout.fillWidth: true; font.pixelSize: 12 }
                        Switch { id: cudaToggle; checked: false }
                    }
                    RowLayout {
                        Label { text: "Sway (webtop):"; Layout.fillWidth: true; font.pixelSize: 12 }
                        Switch { id: webtopToggle; checked: false }
                    }
                    RowLayout {
                        Label { text: "Plasma:"; Layout.fillWidth: true; font.pixelSize: 12 }
                        Switch { id: plasmaToggle; checked: true }
                    }
                }
            }

            // Save button
            Button {
                text: "Save Settings"
                Layout.alignment: Qt.AlignRight
                onClicked: {
                    // TODO: write to cellar.toml and git commit
                    root.showToast("Settings saved (deploy to apply)", false)
                }
                font.pixelSize: 13
            }
        }
    }
}
