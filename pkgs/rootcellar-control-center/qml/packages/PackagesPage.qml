import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: page
    property var cellarBackend: null

    // Sub-view selector
    TabBar {
        id: subTabBar
        Layout.fillWidth: true
        Layout.margins: 8

        background: Rectangle { color: "#181825" }

        Repeater {
            model: ["Featured", "Search", "System", "Local", "Frozen"]
            TabButton {
                text: modelData
                font.pixelSize: 12
                width: implicitWidth
                contentItem: Label {
                    text: parent.text
                    font: parent.font
                    color: subTabBar.currentIndex === index ? "#cdd6f4" : "#6c7086"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    color: subTabBar.currentIndex === index ? "#313244" : "transparent"
                }
            }
        }
    }

    StackLayout {
        currentIndex: subTabBar.currentIndex
        Layout.fillWidth: true
        Layout.fillHeight: true

        // Featured
        ScrollView {
            ListView {
                id: featuredList
                model: ListModel { id: featuredModel }
                delegate: PackageRow {
                    width: featuredList.width
                    packageName: model.name
                    description: model.description
                    state: model.pkgState
                    cellarBackend: page.cellarBackend
                }
            }
        }

        // Search
        ColumnLayout {
            spacing: 8
            Layout.margins: 8

            TextField {
                id: searchField
                Layout.fillWidth: true
                placeholderText: "Search nixpkgs..."
                color: "#cdd6f4"
                placeholderTextColor: "#6c7086"
                background: Rectangle {
                    radius: 6
                    color: "#313244"
                    border.color: searchField.activeFocus ? "#a06be0" : "#45475a"
                }
                onAccepted: {
                    if (cellarBackend) cellarBackend.search(text)
                }
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                ListView {
                    id: searchResults
                    model: ListModel { id: searchModel }
                    delegate: PackageRow {
                        width: searchResults.width
                        packageName: model.name
                        description: model.description
                        state: model.pkgState
                        cellarBackend: page.cellarBackend
                    }
                }
            }
        }

        // System
        ScrollView {
            ListView {
                id: systemList
                model: ListModel { id: systemModel }
                delegate: PackageRow {
                    width: systemList.width
                    packageName: model.name
                    description: model.description
                    state: "system"
                    cellarBackend: page.cellarBackend
                }
            }
        }

        // Local
        ScrollView {
            ListView {
                id: localList
                model: ListModel { id: localModel }
                delegate: PackageRow {
                    width: localList.width
                    packageName: model.name
                    description: model.url
                    state: "local"
                    cellarBackend: page.cellarBackend
                }
            }
        }

        // Frozen
        ScrollView {
            ListView {
                id: frozenList
                model: ListModel { id: frozenModel }
                delegate: PackageRow {
                    width: frozenList.width
                    packageName: model.name
                    description: ""
                    state: "frozen"
                    cellarBackend: page.cellarBackend
                }
            }
        }
    }

    // Load data when visible
    Component.onCompleted: {
        if (cellarBackend) {
            cellarBackend.loadFeatured()
            cellarBackend.loadSystem()
            cellarBackend.loadProfile()
            cellarBackend.loadFrozen()
        }
    }

    Connections {
        target: cellarBackend
        function onFeaturedReady(tsv) { /* parse TSV into featuredModel */ }
        function onSystemReady(tsv) { /* parse TSV into systemModel */ }
        function onProfileReady(json) { /* parse JSON into localModel */ }
        function onFrozenReady(json) { /* parse JSON into frozenModel */ }
        function onSearchResultsReady(json) { /* parse JSON into searchModel */ }
        function onSuccess(success, msg) {
            root.showToast(msg, !success)
        }
    }
}
