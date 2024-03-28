/*
 * Copyright (C) 2023  UBports Foundation
 * Copytight (C) 2023  Maciej Sopyło
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * screenrecorder is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

import QtQuick 2.7
import Lomiri.Components 1.3
import Lomiri.Components.Pickers 1.0
import Lomiri.Content 1.1
import QtQuick.Controls 2.5
import QtQuick.Layouts 1.3
import QtQuick.Window 2.12
import QtGraphicalEffects 1.12
import Qt.labs.settings 1.0
import GSettings 1.0
import Controller 1.0

MainView {
    id: root
    objectName: "mainView"
    applicationName: "screenrecorder.ubports"
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    QtObject {
        id: d

        function checkAppLifecycleExemption() {
            const appidList = gsettings.lifecycleExemptAppids;
            if (!appidList) {
                return false;
            }
            return appidList.includes(Qt.application.name);
        }

        function setAppLifecycleExemption() {
            if (!d.checkAppLifecycleExemption()) {
                const appidList = gsettings.lifecycleExemptAppids;
                const newList = appidList.slice();
                newList.push(Qt.application.name);
                gsettings.lifecycleExemptAppids = newList;
            }
        }

        function unsetAppLifecycleExemption() {
            if (d.checkAppLifecycleExemption()) {
                const appidList = gsettings.lifecycleExemptAppids;
                const index = appidList.indexOf(Qt.application.name);
                const newList = appidList.slice();
                if (index > -1) {
                    newList.splice(index, 1);
                }
                gsettings.lifecycleExemptAppids = newList;
            }
        }

        function startRecording() {
            recordingButton.recording = true;
            d.setAppLifecycleExemption();
            Controller.start(Screen.width, Screen.height, 1.0/*resolution.checkedButton.value*/, 30/*fps.checkedButton.value*/);
        }

        function stopRecording() {
            recordingButton.recording = false;
            Controller.stop();
            d.unsetAppLifecycleExemption();
        }
    }

    // cleanup in case it crashes
    Component.onCompleted: d.unsetAppLifecycleExemption()
    Component.onDestruction: d.unsetAppLifecycleExemption()

    GSettings {
        id: gsettings
        schema.id: "com.canonical.qtmir"
    }

    Page {
        id: mainPage
        anchors.fill: parent

        header: PageHeader {
            id: header
            title: i18n.tr("Screen recorder")
            StyleHints {
                foregroundColor: "white"
                backgroundColor: "#213d3d"
                dividerColor: "transparent"
            }
        }

        RadialGradient {
            anchors.fill: parent
            angle: 45
            horizontalOffset: 0 - (parent.width / 3)
            verticalOffset: parent.height - (parent.height / 3)
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#2b6f6f" }
                GradientStop { position: 0.88; color: "#213d3d" }
            }
        }

        ColumnLayout {
            spacing: units.gu(2)

            anchors {
                margins: units.gu(2)
                fill: parent
            }

            Item {
                Layout.fillHeight: true
            }

            Label {
                text: i18n.tr("The recording indicator will not show up until you restart your device or Lomiri once.")
                wrapMode: Text.WordWrap
                color: "white"
                Layout.fillWidth: true
            }

/*
            Label {
                text: i18n.tr("Resolution scale (not working atm):")
                color: "white"
                Layout.fillWidth: true
            }

            ButtonGroup {
                id: resolution
                buttons: resolutionRow.children
            }

            Row {
                id: resolutionRow

                RadioButton {
                    property real value: 1.0
                    checked: true
                    enabled: false
                    text: "100%"
                }

                RadioButton {
                    property real value: 0.75
                    enabled: false
                    text: "75%"
                }

                RadioButton {
                    property real value: 0.5
                    enabled: false
                    text: "50%"
                }

                RadioButton {
                    property real value: 0.25
                    enabled: false
                    text: "25%"
                }
            }

            Label {
                text: i18n.tr("Framerate:")
                color: "white"
                Layout.fillWidth: true
            }

            ButtonGroup {
                id: fps
                buttons: fpsRow.children
            }

            Row {
                id: fpsRow

                RadioButton {
                    property int value: 30
                    checked: true
                    text: "30"
                }

                RadioButton {
                    property int value: 60
                    text: "60"
                }
            }
*/

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: units.gu(1)

                Rectangle {
                    id: recordingButton
                    color: recordingButtonMouseArea.pressed ? "#77FF0000" : !recording ? "#99FF0000" :  "#FFFF0000"
                    width: units.gu(16)
                    height: width
                    radius: width / 2
                    border.color: "darkred"
                    border.width: units.gu(0.5)
                    Behavior on color { ColorAnimation { duration: 100 } }

                    property bool recording : false

                    BusyIndicator {
                        id: indicator
                        running: recordingButton.recording
                        visible: running
                        anchors.centerIn: parent
                    }

                    MouseArea {
                        id: recordingButtonMouseArea
                        anchors.fill: parent
                        onClicked: {
                            if (!recordingButton.recording)
                                d.startRecording()
                            else
                                d.stopRecording()
                        }
                    }
                }
            }

            Item {
                Layout.fillHeight: true
            }
        }

        ContentPeerPicker {
            id: picker
            anchors.fill: parent
            visible: false
            showTitle: false
            contentType: ContentType.Videos
            handler: ContentHandler.Destination

            property var activeTransfer : null
            property string targetUrl : ""

            ContentItem {
                id: contentItem
            }

            onPeerSelected: {
                peer.selectionType = ContentTransfer.Single
                picker.activeTransfer = peer.request()
                picker.activeTransfer.stateChanged.connect(function() {
                    if (picker.activeTransfer.state === ContentTransfer.InProgress) {
                        console.log("In progress");
                        contentItem.url = picker.targetUrl
                        contentItem.text = "recording_" + Date.now() + ".mp4"
                        console.log("Transfering: " + contentItem.url + " " + contentItem.text)
                        picker.activeTransfer.items = new Array
                        picker.activeTransfer.items.push(contentItem)
                        picker.activeTransfer.state = ContentTransfer.Charged;
                    }
                    if (picker.activeTransfer.state === ContentTransfer.Charged) {
                        console.log("Charged");
                        picker.activeTransfer = null
                    }
                })
                picker.visible = false
            }
        }

        Connections {
            target: Controller

            onFileSaved: {
                picker.targetUrl = "file://" + path
                picker.visible = true
            }
        }
    }

    Connections {
        target: UriHandler

        onOpened: {
            if (!uris.length) {
                return;
            }

            // the only thing we want to handle is stopping the recording
            d.stopRecording();
        }
    }
}
