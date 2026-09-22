import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: row
    property string packageName: ""
    property string description: ""
    property string state: ""  // "system", "local", "frozen", or ""
    property var cellarBackend: null
    height: 56
    color: hovered ? "#313244" : "transparent"
    radius: 6

    property bool hovered: false
    onHoveredChanged: color = hovered ? "#313244" : "transparent"

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: row.hovered = true
        onExited: row.hovered = false
    }

    RowLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 12

        // State badges
        Row {
            spacing: 4
            visible: row.state !== ""
            Repeater {
                model: row.state === "" ? [] : [row.state]
                Rectangle {
                    width: badgeLabel.implicitWidth + 12
                    height: 20
                    radius: 10
                    color: modelData === "system" ? "#45475a"
                         : modelData === "local" ? "#89b4fa"
                         : modelData === "frozen" ? "#a06be0"
                         : "#45475a"
                    Label {
                        id: badgeLabel
                        anchors.centerIn: parent
                        text: modelData
                        font.pixelSize: 10
                        color: "#cdd6f4"
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            Label {
                text: row.packageName
                font.bold: true
                font.pixelSize: 13
                color: "#cdd6f4"
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Label {
                text: row.description
                font.pixelSize: 11
                color: "#a6adc8"
                elide: Text.ElideRight
                Layout.fillWidth: true
                maximumLineCount: 1
            }
        }

        // Action buttons
        Row {
            spacing: 6

            Button {
                text: "Install"
                visible: row.state === ""
                onClicked: if (cellarBackend) cellarBackend.install(row.packageName)
                font.pixelSize: 11
            }
            Button {
                text: "Remove"
                visible: row.state === "local"
                onClicked: if (cellarBackend) cellarBackend.uninstall(row.packageName)
                font.pixelSize: 11
            }
            Button {
                text: "Freeze"
                visible: row.state === ""
                onClicked: if (cellarBackend) cellarBackend.freeze(row.packageName)
                font.pixelSize: 11
            }
            Button {
                text: "Unfreeze"
                visible: row.state === "frozen"
                onClicked: if (cellarBackend) cellarBackend.unfreeze(row.packageName)
                font.pixelSize: 11
            }
        }
    }
}
