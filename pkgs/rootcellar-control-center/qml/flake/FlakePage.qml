import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: page
    property var flakeBackend: null

    // Header
    RowLayout {
        Layout.fillWidth: true
        Layout.margins: 12
        spacing: 12

        Label {
            text: "Flake Inputs"
            font.bold: true
            font.pixelSize: 16
            color: "#cdd6f4"
        }

        Item { Layout.fillWidth: true }

        Label {
            id: lockInfo
            text: ""
            font.pixelSize: 11
            color: "#6c7086"
        }

        Button {
            text: "Refresh"
            onClicked: if (flakeBackend) flakeBackend.loadMetadata()
            font.pixelSize: 12
        }
    }

    // Dirty warning
    Rectangle {
        Layout.fillWidth: true
        Layout.margins: 8
        height: dirtyLabel.implicitHeight + 16
        color: "#f9e2af"
        radius: 6
        visible: false
        id: dirtyWarning

        Label {
            id: dirtyLabel
            anchors.centerIn: parent
            text: "Working tree is dirty — flake metadata may be stale"
            color: "#1e1e2e"
            font.pixelSize: 12
        }
    }

    // Inputs list
    ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.margins: 8

        ListView {
            id: inputsList
            model: ListModel { id: inputsModel }
            spacing: 4

            delegate: Rectangle {
                width: inputsList.width
                height: 80
                color: inputHover.hovered ? "#313244" : "#1e1e2e"
                radius: 8

                MouseArea {
                    id: inputHover
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 16

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4

                        Row {
                            spacing: 8
                            Label {
                                text: model.name
                                font.bold: true
                                font.pixelSize: 14
                                color: "#cdd6f4"
                            }
                            Rectangle {
                                width: stalenessLabel.implicitWidth + 8
                                height: 16
                                radius: 8
                                color: model.staleness === "fresh" ? "#a6e3a1"
                                     : model.staleness === "stale" ? "#f9e2af"
                                     : "#f38ba8"
                                Label {
                                    id: stalenessLabel
                                    anchors.centerIn: parent
                                    text: model.staleness
                                    font.pixelSize: 9
                                    color: "#1e1e2e"
                                }
                            }
                        }

                        Row {
                            spacing: 12
                            Label {
                                text: "Branch: " + model.branch
                                font.pixelSize: 11
                                color: "#a6adc8"
                            }
                            Label {
                                text: "Rev: " + model.rev
                                font.pixelSize: 11
                                color: "#a6adc8"
                                font.family: "monospace"
                            }
                            Label {
                                text: model.age
                                font.pixelSize: 11
                                color: "#6c7086"
                            }
                        }

                        Label {
                            text: model.follows !== "" ? "Follows: " + model.follows : ""
                            font.pixelSize: 10
                            color: "#585b70"
                            visible: model.follows !== ""
                        }
                    }

                    Row {
                        spacing: 6
                        Button {
                            text: "Update"
                            onClicked: if (flakeBackend) flakeBackend.updateInput(model.name)
                            font.pixelSize: 11
                        }
                        Button {
                            text: "Pin..."
                            onClicked: pinDialog.open()
                            font.pixelSize: 11
                        }
                    }
                }

                // Pin dialog
                Dialog {
                    id: pinDialog
                    title: "Pin " + model.name
                    modal: true
                    anchors.centerIn: parent
                    standardButtons: Dialog.Ok | Dialog.Cancel

                    ColumnLayout {
                        Label { text: "Enter commit SHA:" }
                        TextField {
                            id: pinField
                            placeholderText: "abc123..."
                        }
                    }

                    onAccepted: {
                        if (flakeBackend && pinField.text.length > 0)
                            flakeBackend.pinInput(model.name, pinField.text)
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        if (flakeBackend) flakeBackend.loadMetadata()
    }

    Connections {
        target: flakeBackend
        function onMetadataReady(json) {
            // Parse JSON and populate inputsModel
            inputsModel.clear()
            try {
                var data = JSON.parse(json)
                var inputs = data.inputs || {}
                for (var name in inputs) {
                    var input = inputs[name]
                    var locked = input.locked || {}
                    var original = input.original || {}
                    var rev = (locked.rev || "").substring(0, 12)
                    var branch = original.ref || "default"
                    var lastMod = locked.lastModified || 0
                    var age = formatAge(lastMod)
                    var staleness = computeStaleness(lastMod)
                    var follows = input.inputs ? JSON.stringify(input.inputs) : ""

                    inputsModel.append({
                        name: name,
                        branch: branch,
                        rev: rev,
                        age: age,
                        staleness: staleness,
                        follows: follows
                    })
                }
                dirtyWarning.visible = data.dirtyRevision !== undefined
                lockInfo.text = "Lock v" + (data.version || "?")
            } catch(e) {}
        }
        function onCostWarning(msg) {
            root.showToast(msg, true)
        }
        function onOperationFinished(ok, msg) {
            root.showToast(msg, !ok)
        }
    }

    function formatAge(timestamp) {
        if (timestamp === 0) return "unknown"
        var now = Math.floor(Date.now() / 1000)
        var diff = now - timestamp
        if (diff < 3600) return Math.floor(diff / 60) + "m ago"
        if (diff < 86400) return Math.floor(diff / 3600) + "h ago"
        return Math.floor(diff / 86400) + "d ago"
    }

    function computeStaleness(timestamp) {
        if (timestamp === 0) return "unknown"
        var now = Math.floor(Date.now() / 1000)
        var diff = now - timestamp
        if (diff < 604800) return "fresh"  // < 7 days
        if (diff < 2592000) return "stale"  // < 30 days
        return "old"
    }
}
