import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    property var appsToUninstall: ([])
    property var appsToEnable: ([])
    property var launchableApps: ([])
    property bool isPhoneVisible: false
    property bool isFDroidInstalled: false
    property bool searchAttempted: false
    property string pendingPlayStorePkg: ""

    property string phoneManufacturer: "Unknown"
    property string phoneModel: "Unknown"
    property string phoneAndroid: "Unknown"
    property string phoneSerial: "Unknown"

    // Dynamic Storage Properties
    property string storageTotal: "-"
    property string storageUsed: "-"
    property string storageAvail: "-"

    // Target Android Download folder path
    property string remoteSharedFolder: "/sdcard/Download"

    // Malware Scanner Properties
    property bool depsInstalled: false
    property string scanStatusMessage: ""
    property string detectedInfectedFile: ""
    property bool isScanning: false

    property var friendlyNames: ({
        "com.google.android.gm": "Gmail",
        "com.google.android.apps.docs": "Google Drive",
        "com.google.android.apps.tachyon": "Google Meet (Duo)",
                                 "com.google.android.projection.gearhead": "Android Auto",
                                 "com.google.android.googlequicksearchbox": "Google Search",
                                 "com.google.android.tts": "Google Speech / Text-to-Speech",
                                 "com.google.android.as": "Android System Intelligence",
                                 "com.google.android.turbo": "Device Health Services",
                                 "com.google.android.gms": "Google Play Services",
                                 "com.google.ar.lens": "Google Lens",
                                 "com.android.chrome": "Google Chrome",
                                 "com.google.android.youtube": "YouTube",
                                 "com.google.android.apps.photos": "Google Photos",
                                 "com.google.android.apps.messaging": "Messages"
    })

    property var protectedPackages: [
        "android",
        "com.android.systemui",
        "com.android.settings",
        "com.android.phone",
        "com.android.providers.telephony",
        "com.android.providers.media",
        "com.android.providers.settings",
        "com.android.packageinstaller",
        "com.android.keychain",
        "com.android.shell",
        "com.android.permissioncontroller",
        "com.android.vending",
        "com.android.bluetooth",
        "com.android.nfc",
        "com.android.se",
        "com.android.inputmethod.latin",
        "com.google.android.gms",
        "com.google.android.setupwizard",
        "com.google.android.documentsui",
        "com.google.android.apps.restore",
        "com.google.android.health.connect.backuprestore",
        "com.samsung.android.incallui",
        "com.samsung.android.launcher",
        "com.samsung.android.dialer",
        "com.samsung.android.app.contacts",
        "com.sec.android.app.camera",
        "com.sec.android.app.launcher",
        "com.sec.android.app.clockpackage",
        "com.sec.android.app.myfiles",
        "com.miui.home"
    ]

    function isSystemCritical(pkg) {
        let name = pkg.toLowerCase();
        if (protectedPackages.indexOf(pkg) !== -1) return true;

        if (name.includes(".overlay.") ||
            name.includes(".networkstack") ||
            name.includes(".mainline.") ||
            name.includes(".permissioncontroller") ||
            name.includes(".webview") ||
            name.includes(".cellbroadcast") ||
            name.includes(".captiveportallogin") ||
            name.includes(".sdksandbox") ||
            name.includes(".modulemetadata") ||
            name.includes(".configupdater") ||
            name.includes(".onetimeinitializer") ||
            name.includes(".server.deviceconfig") ||
            name.includes(".federatedcompute") ||
            name.includes(".adservices") ||
            name.includes(".ondevicepersonalization") ||
            name.includes(".providers.") ||
            name.includes(".photopicker") ||
            name.includes(".printservice") ||
            name.includes(".packageinstaller") ||
            name.includes(".safetycenter") ||
            name.includes(".connectivity.resources") ||
            name.includes(".ext.shared") ||
            name.includes(".ext.services") ||
            name.includes(".gsf") ||
            name.includes(".as.oss") ||
            name.includes(".feedback") ||
            name.includes(".partnersetup") ||
            name.includes(".hardware.") ||
            name.includes(".system.") ||
            name.includes(".framework.") ||
            name.includes("vendor.") ||
            name.includes("qualcomm") ||
            name.includes("samsung.framework") ||
            name.includes("sec.android.provider")) {
            return true;
            }
            return false;
    }

    function formatDisplayName(pkg) {
        if (friendlyNames[pkg]) {
            return friendlyNames[pkg];
        }

        let parts = pkg.split(".");
        let lastPart = parts[parts.length - 1];

        if (lastPart === "android" || lastPart === "app" || lastPart === "apk") {
            lastPart = parts[parts.length - 2] || lastPart;
        }

        let cleaned = lastPart
        .replace("com.google.android.apps.", "")
        .replace("com.google.android.", "")
        .replace("com.google.", "")
        .replace("com.android.", "")
        .replace("com.sec.android.app.", "")
        .replace("com.sec.android.", "")
        .replace("com.samsung.android.app.", "")
        .replace("com.samsung.android.", "")
        .replace("com.", "");

        return cleaned.charAt(0).toUpperCase() + cleaned.slice(1);
    }

    function recalculateChanges() {
        let uninstalls = [];
        let enables = [];

        let checkModel = function(model) {
            if (!model) return;
            for (let i = 0; i < model.count; i++) {
                let item = model.get(i);
                if (item &&
                    item.rawPkg !== undefined &&
                    item.isInstalled !== undefined &&
                    item.originalState !== undefined) {

                    if (item.isInstalled && !item.originalState) {
                        enables.push(item.rawPkg);
                    } else if (!item.isInstalled && item.originalState) {
                        uninstalls.push(item.rawPkg);
                    }
                    }
            }
        };

        checkModel(googleAppsModel);
        checkModel(thirdPartyAppsModel);
        checkModel(searchResultsModel);

        appsToUninstall = uninstalls;
        appsToEnable = enables;
    }

    function sortModel(model) {
        if (!model) return;
        let items = [];
        for (let i = 0; i < model.count; i++) {
            let item = model.get(i);
            if (item && item.rawPkg !== undefined && item.displayName !== undefined) {
                items.push({
                    displayName: item.displayName,
                    rawPkg: item.rawPkg,
                    isInstalled: item.isInstalled,
                    originalState: item.originalState
                });
            }
        }

        items.sort(function(a, b) {
            let activeA = a.isInstalled;
            let activeB = b.isInstalled;
            let isGoogleA = a.rawPkg.toLowerCase().includes("google") || a.rawPkg === "com.android.chrome";
            let isGoogleB = b.rawPkg.toLowerCase().includes("google") || b.rawPkg === "com.android.chrome";

            if (!isGoogleA && !isGoogleB) {
                if (activeA !== activeB) return activeA ? -1 : 1;
            }

            if (activeA === activeB) return a.displayName.localeCompare(b.displayName);
            return activeA ? -1 : 1;
        });

        model.clear();
        for (let i = 0; i < items.length; i++) {
            model.append(items[i]);
        }
    }

    PanelWindow {
        id: window
        anchors { top: true; bottom: true; right: true }
        implicitWidth: 680
        visible: true
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrLayershell.OnDemand
        exclusiveZone: 0

        mask: Region {
            item: body
        }

        Rectangle {
            id: body
            anchors.fill: parent
            color: "#121317"
            opacity: 0.94
            border.color: "#555839"
            border.width: 1
            radius: 16

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    height: 54
                    color: Qt.rgba(0.22, 0.24, 0.21, 0.85)
                    radius: 12
                    border.color: "#b0ac63"
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Debloat Android Phone"
                        color: "#dde5a2"
                        font.pixelSize: 22
                        font.family: "Monospace"
                        font.bold: true
                        font.letterSpacing: 1
                    }
                }

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    spacing: 6
                    background: Rectangle { color: "transparent" }

                    onCurrentIndexChanged: {
                        if (currentIndex === 2) {
                            searchField.forceActiveFocus();
                        } else if (currentIndex === 4) {
                            sharedTabHelper.onTabSelected();
                        } else if (currentIndex === 5) {
                            monitoringTabHelper.onTabSelected();
                        } else {
                            monitoringTabHelper.onTabDeselected();
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Google"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Third-Party"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Search"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Reboot"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Shared"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Monitor"
                            color: parent.checked ? "#dde5a2" : "#888888"
                            font.pixelSize: 12
                            font.family: "Monospace"
                            font.bold: parent.checked
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                        background: Rectangle {
                            color: parent.checked ? "#363c30" : "transparent"
                            border.color: parent.checked ? "#555839" : "transparent"
                            border.width: 1
                            radius: 6
                        }
                    }
                }

                Rectangle {
                    id: appViewsContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    radius: 8
                    border.width: 1
                    border.color: "#555839"

                    StackLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        currentIndex: tabBar.currentIndex

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: statusScrollView.visible
                                    clip: true

                                    TextArea {
                                        id: statusText
                                        readOnly: true
                                        text: "Initializing system check...\n"
                                        color: "#dde5a2"
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        background: null
                                        wrapMode: TextEdit.WrapAnywhere
                                    }
                                }

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: !statusScrollView.visible
                                    clip: true

                                    ListView {
                                        id: googleListView
                                        model: ListModel { id: googleAppsModel }
                                        spacing: 6
                                        delegate: pkgDelegate
                                    }
                                }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                ScrollView {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    visible: !statusScrollView.visible
                                    clip: true

                                    ListView {
                                        id: thirdPartyListView
                                        model: ListModel { id: thirdPartyAppsModel }
                                        spacing: 6
                                        delegate: pkgDelegate
                                    }
                                }
                            }
                        }

                        // Search Tab
                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    TextField {
                                        id: searchField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 42
                                        placeholderText: "Search for apps"
                                        placeholderTextColor: "#a8ad78"
                                        color: "#dde5a2"
                                        font.family: "Monospace"
                                        font.pixelSize: 14
                                        leftPadding: 12
                                        rightPadding: 12

                                        background: Rectangle {
                                            color: "#1a1c18"
                                            border.color: "#555839"
                                            border.width: 1
                                            radius: 6
                                        }

                                        onAccepted: triggerPhoneSearch()
                                    }

                                    Button {
                                        id: searchButton
                                        Layout.preferredWidth: 110
                                        Layout.preferredHeight: 42
                                        text: "Search"
                                        font.pixelSize: 14
                                        font.family: "Monospace"
                                        scale: pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                        background: Rectangle {
                                            radius: 6
                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: "#dde5a2"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: triggerPhoneSearch()
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Text {
                                        anchors.centerIn: parent
                                        visible: searchResultsModel.count === 0 && searchAttempted
                                        text: "no app found"
                                        color: "#b0ac63"
                                        font.pixelSize: 14
                                        font.family: "Monospace"
                                    }

                                    ScrollView {
                                        anchors.fill: parent
                                        visible: searchResultsModel.count > 0
                                        clip: true

                                        ListView {
                                            id: searchResultsListView
                                            model: ListModel { id: searchResultsModel }
                                            spacing: 6
                                            delegate: pkgDelegate
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Button {
                                        Layout.preferredWidth: 220
                                        Layout.preferredHeight: 46
                                        text: "Reboot recovery"
                                        font.pixelSize: 14
                                        font.family: "Monospace"
                                        scale: pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                        background: Rectangle {
                                            radius: 8
                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: "#dde5a2"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: rebootRecoveryProc.running = true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "⚠️ Reboots your phone into Recovery Mode. Used for system updates, wiping caches, factory resets, or sideloading packages."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Item { Layout.preferredHeight: 10 }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Button {
                                        Layout.preferredWidth: 220
                                        Layout.preferredHeight: 46
                                        text: "Reboot bootloader"
                                        font.pixelSize: 14
                                        font.family: "Monospace"
                                        scale: pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                        background: Rectangle {
                                            radius: 8
                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: "#dde5a2"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: rebootBootloaderProc.running = true
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        text: "⚠️ Reboots your phone into Bootloader / Fastboot mode. Used for flashing raw partition images, unlocking bootloaders, or low-level firmware flashing."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        wrapMode: Text.WordWrap
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // Shared Tab View
                        Item {
                            id: sharedTabHelper

                            ListModel {
                                id: sharedFolderModel
                            }

                            function readDirectoryContents() {
                                sharedFolderModel.clear();
                                sharedFileProc.command = ["adb", "shell", "ls", "-1p", remoteSharedFolder + "/"];
                                sharedFileProc.running = true;
                            }

                            function onTabSelected() {
                                readDirectoryContents();
                            }

                            Process {
                                id: sharedFileProc
                                command: []

                                stdout: SplitParser {
                                    onRead: data => {
                                        let fileName = data.trim();
                                        if (fileName.length > 0 && fileName !== "." && fileName !== "..") {
                                            let isDir = fileName.endsWith("/");
                                            let cleanName = isDir ? fileName.slice(0, -1) : fileName;

                                            sharedFolderModel.append({
                                                entryName: cleanName,
                                                fileName: cleanName
                                            });
                                        }
                                    }
                                }
                            }

                            Process {
                                id: adbPushProc
                                property var fileQueue: []

                                function pushNext() {
                                    if (fileQueue.length > 0) {
                                        let filePath = fileQueue.shift();
                                        adbPushProc.command = ["adb", "push", filePath, remoteSharedFolder + "/"];
                                        adbPushProc.running = true;
                                    } else {
                                        sharedTabHelper.readDirectoryContents();
                                    }
                                }

                                onExited: exitCode => {
                                    pushNext();
                                }
                            }

                            Process {
                                id: adbPullProc
                                command: []
                                property string pulledFileName: ""

                                onExited: exitCode => {
                                    if (exitCode === 0) {
                                        statusNoticeText.text = "Pulled " + pulledFileName + " to ~/Downloads";
                                    } else {
                                        statusNoticeText.text = "Failed to pull " + pulledFileName;
                                    }
                                    statusNoticeTimer.restart();
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Path: " + remoteSharedFolder
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        width: 90
                                        height: 32
                                        text: "Refresh"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        scale: pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                        background: Rectangle {
                                            radius: 6
                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: "#dde5a2"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: sharedTabHelper.readDirectoryContents()
                                    }
                                }

                                Rectangle {
                                    id: statusNoticeRect
                                    Layout.fillWidth: true
                                    height: 36
                                    color: "#282a20"
                                    radius: 6
                                    border.color: "#b0ac63"
                                    border.width: 1

                                    Text {
                                        id: statusNoticeText
                                        anchors.centerIn: parent
                                        color: "#dde5a2"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        text: "Ready"
                                    }

                                    Timer {
                                        id: statusNoticeTimer
                                        interval: 4000
                                        onTriggered: statusNoticeText.text = "Ready"
                                    }
                                }

                                DropArea {
                                    id: dropArea
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    onDropped: drop => {
                                        if (drop.hasUrls) {
                                            let filesToPush = [];
                                            for (let i = 0; i < drop.urls.length; i++) {
                                                let path = drop.urls[i].toString();
                                                if (path.startsWith("file://")) {
                                                    path = path.substring(7);
                                                }
                                                path = decodeURIComponent(path);
                                                filesToPush.push(path);
                                            }

                                            if (filesToPush.length > 0) {
                                                statusNoticeText.text = "Uploading files to phone...";
                                                adbPushProc.fileQueue = filesToPush;
                                                if (!adbPushProc.running) {
                                                    adbPushProc.pushNext();
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        anchors.fill: parent
                                        color: dropArea.containsDrag ? "#282a20" : "#1a1c18"
                                        radius: 8
                                        border.color: dropArea.containsDrag ? "#dde5a2" : "#555839"
                                        border.width: dropArea.containsDrag ? 2 : 1

                                        ListView {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            model: sharedFolderModel
                                            clip: true

                                            delegate: ItemDelegate {
                                                width: ListView.view.width
                                                height: 44
                                                background: Rectangle {
                                                    color: parent.hovered ? Qt.rgba(0.28, 0.30, 0.25, 0.5) : "transparent"
                                                    radius: 4
                                                }
                                                contentItem: RowLayout {
                                                    spacing: 10
                                                    Text {
                                                        text: model.fileName !== "" ? "📁" : "📄"
                                                        font.pixelSize: 14
                                                    }
                                                    Text {
                                                        text: model.entryName
                                                        color: "#dde5a2"
                                                        font.pixelSize: 12
                                                        font.family: "Monospace"
                                                        Layout.fillWidth: true
                                                        elide: Text.ElideMiddle
                                                    }

                                                    Button {
                                                        width: 90
                                                        height: 28
                                                        text: "Pull to PC"
                                                        visible: model.fileName !== ""
                                                        font.pixelSize: 11
                                                        font.family: "Monospace"
                                                        scale: pressed ? 0.96 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                                        background: Rectangle {
                                                            radius: 4
                                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                                            border.color: Qt.darker("#555839", 1.2)
                                                            border.width: 1
                                                        }

                                                        contentItem: Text {
                                                            text: parent.text
                                                            font: parent.font
                                                            color: "#dde5a2"
                                                            horizontalAlignment: Text.AlignHCenter
                                                            verticalAlignment: Text.AlignVCenter
                                                        }

                                                        onClicked: {
                                                            let fName = model.fileName;
                                                            adbPullProc.pulledFileName = fName;
                                                            adbPullProc.command = ["bash", "-c", "adb pull \"" + remoteSharedFolder + "/" + fName + "\" \"$HOME/Downloads/\""];
                                                            statusNoticeText.text = "Pulling " + fName + "...";
                                                            adbPullProc.running = true;
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: sharedFolderModel.count === 0 && !dropArea.containsDrag
                                            text: "Folder is empty or device not connected\n(Drag & drop files here to upload)"
                                            horizontalAlignment: Text.AlignHCenter
                                            color: "#b0ac63"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: dropArea.containsDrag
                                            text: "Drop files to copy to phone..."
                                            color: "#dde5a2"
                                            font.pixelSize: 14
                                            font.bold: true
                                            font.family: "Monospace"
                                        }
                                    }
                                }
                            }
                        }

                        // Monitoring Tab View
                        Item {
                            id: monitoringTabHelper

                            ListModel {
                                id: monitoringModel
                            }

                            function onTabSelected() {
                                monitoringModel.clear();
                                adbTopProc.running = true;
                                topRefreshTimer.restart();
                            }

                            function onTabDeselected() {
                                adbTopProc.running = false;
                                topRefreshTimer.stop();
                            }

                            Timer {
                                id: topRefreshTimer
                                interval: 3000
                                repeat: true
                                running: false
                                onTriggered: {
                                    if (!adbTopProc.running) {
                                        adbTopProc.running = true;
                                    }
                                }
                            }

                            Process {
                                id: adbTopProc
                                command: ["adb", "shell", "top", "-b", "-n", "1"]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let block = text.trim();
                                        if (block.length > 0) {
                                            let lines = block.split("\n");
                                            monitoringModel.clear();

                                            for (let i = 0; i < lines.length; i++) {
                                                let line = lines[i].trim();
                                                if (line.length > 0) {
                                                    monitoringModel.append({ lineText: line });
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Live Process Monitor (adb shell top)"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        width: 90
                                        height: 32
                                        text: "Refresh"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        scale: pressed ? 0.96 : 1.0
                                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                        background: Rectangle {
                                            radius: 6
                                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }

                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: "#dde5a2"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }

                                        onClicked: {
                                            monitoringModel.clear();
                                            adbTopProc.running = true;
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "#1a1c18"
                                    radius: 8
                                    border.color: "#555839"
                                    border.width: 1

                                    ListView {
                                        anchors.fill: parent
                                        anchors.margins: 6
                                        model: monitoringModel
                                        clip: true
                                        interactive: true

                                        delegate: ItemDelegate {
                                            width: ListView.view.width
                                            height: model.lineText.indexOf("PID") !== -1 || model.lineText.indexOf("CPU%") !== -1 ? 26 : 20

                                            background: Rectangle {
                                                color: (model.lineText.indexOf("PID") !== -1 && (model.lineText.indexOf("PR") !== -1 || model.lineText.indexOf("CPU") !== -1)) ? "#2f3325" : "transparent"
                                                radius: 4
                                            }

                                            contentItem: Text {
                                                text: model.lineText
                                                color: (model.lineText.indexOf("PID") !== -1 && (model.lineText.indexOf("PR") !== -1 || model.lineText.indexOf("CPU") !== -1)) ? "#ffffff" : "#dde5a2"
                                                font.pixelSize: (model.lineText.indexOf("PID") !== -1 && (model.lineText.indexOf("PR") !== -1 || model.lineText.indexOf("CPU") !== -1)) ? 12 : 11
                                                font.bold: (model.lineText.indexOf("PID") !== -1 && (model.lineText.indexOf("PR") !== -1 || model.lineText.indexOf("CPU") !== -1))
                                                font.family: "Monospace"
                                                elide: Text.ElideRight
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: monitoringModel.count === 0
                                        text: "Waiting for monitoring data..."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                    }
                                }
                            }
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        text: isPhoneVisible ? "Close phone" : "Show phone"
                        font.pixelSize: 14
                        font.family: "Monospace"
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                            border.color: Qt.darker("#555839", 1.2)
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#dde5a2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: {
                            if (isPhoneVisible) {
                                scrcpyReconnectTimer.stop();
                                isPhoneVisible = false;
                                killScrcpyProc.running = true;
                            } else {
                                isPhoneVisible = true;
                                killScrcpyProc.running = false;
                                startScrcpyProc.running = true;
                            }
                        }
                    }

                    // Shared Tab - Scan Downloads / Quarantine Button Section
                    ColumnLayout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: tabBar.currentIndex === 4
                        spacing: 6

                        Button {
                            id: scanButton
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 240
                            Layout.preferredHeight: 44
                            text: isScanning ? "Scanning..." : (detectedInfectedFile !== "" ? "Quarantine file" : "Scan Downloads")
                            font.pixelSize: 14
                            font.family: "Monospace"
                            enabled: !isScanning
                            scale: pressed ? 0.96 : 1.0
                            Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                            background: Rectangle {
                                radius: 8
                                color: parent.pressed ? Qt.darker(detectedInfectedFile !== "" ? "#5a2d2d" : "#363c30", 1.1) : (detectedInfectedFile !== "" ? "#4a2424" : "#363c30")
                                border.color: detectedInfectedFile !== "" ? "#d9534f" : Qt.darker("#555839", 1.2)
                                border.width: 1
                            }

                            contentItem: Text {
                                text: parent.text
                                font: parent.font
                                color: detectedInfectedFile !== "" ? "#ff8888" : "#dde5a2"
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }

                            onClicked: {
                                if (!depsInstalled) {
                                    scanStatusMessage = "ClamAV must be installed on your Linux machine to scan downloads.";
                                    return;
                                }

                                if (detectedInfectedFile !== "") {
                                    quarantineProc.command = ["adb", "shell", "rm", "-f", remoteSharedFolder + "/" + detectedInfectedFile];
                                    quarantineProc.running = true;
                                } else {
                                    scanStatusMessage = "Scanning remote downloads folder via ADB...";
                                    isScanning = true;
                                    scanProc.running = true;
                                }
                            }
                        }

                        Text {
                            id: scanStatusText
                            Layout.alignment: Qt.AlignHCenter
                            Layout.preferredWidth: 380
                            text: scanStatusMessage
                            color: detectedInfectedFile !== "" ? "#ff7777" : "#dde5a2"
                            font.pixelSize: 11
                            font.family: "Monospace"
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            visible: scanStatusMessage.length > 0
                        }
                    }

                    Button {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        text: "Re-check Devices"
                        font.pixelSize: 14
                        font.family: "Monospace"
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                            border.color: Qt.darker("#555839", 1.2)
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#dde5a2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: runDiagnostics()
                    }

                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        visible: tabBar.currentIndex === 1

                        RowLayout {
                            anchors.fill: parent
                            spacing: 8

                            Button {
                                id: fdroidBtn
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                text: isFDroidInstalled ? "Open F-Droid" : "Install F-Droid"
                                font.pixelSize: 14
                                font.family: "Monospace"
                                enabled: !installFDroidProc.running && !openFDroidProc.running
                                scale: pressed ? 0.96 : 1.0
                                Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                                background: Rectangle {
                                    radius: 8
                                    color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                                    border.color: Qt.darker("#555839", 1.2)
                                    border.width: 1
                                }

                                contentItem: Text {
                                    text: parent.text
                                    font: parent.font
                                    color: "#dde5a2"
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                onClicked: {
                                    if (isFDroidInstalled) {
                                        openFDroidProc.running = true;
                                    } else {
                                        installFDroidProc.running = true;
                                    }
                                }
                            }

                            ProgressBar {
                                id: fdroidProgress
                                Layout.preferredWidth: 80
                                Layout.fillHeight: true
                                visible: installFDroidProc.running
                                indeterminate: true

                                background: Rectangle {
                                    color: "#1a1c18"
                                    border.color: "#555839"
                                    border.width: 1
                                    radius: 6
                                }

                                contentItem: Item {
                                    implicitWidth: 80
                                    implicitHeight: 12

                                    Rectangle {
                                        id: bar
                                        width: parent.width * 0.4
                                        height: parent.height
                                        radius: 6
                                        color: "#dde5a2"

                                        SequentialAnimation {
                                            running: fdroidProgress.visible
                                            loops: Animation.Infinite
                                            NumberAnimation {
                                                target: bar
                                                property: "x"
                                                from: 0
                                                to: fdroidProgress.width - bar.width
                                                duration: 800
                                                easing.type: Easing.InOutQuad
                                            }
                                            NumberAnimation {
                                                target: bar
                                                property: "x"
                                                from: fdroidProgress.width - bar.width
                                                to: 0
                                                duration: 800
                                                easing.type: Easing.InOutQuad
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Button {
                        id: applyBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        visible: tabBar.currentIndex === 0 || tabBar.currentIndex === 1
                        text: "Apply (" + (appsToUninstall.length + appsToEnable.length) + " Changes)"
                        font.pixelSize: 14
                        font.family: "Monospace"
                        enabled: (appsToUninstall.length + appsToEnable.length) > 0
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.enabled ? (parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30") : "#252627"
                            border.color: parent.enabled ? Qt.darker("#555839", 1.2) : "#3a3a3a"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: parent.enabled ? "#dde5a2" : "#666666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: applyPendingChanges()
                    }

                    Button {
                        id: closeBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        text: "Close OSD"
                        font.pixelSize: 14
                        font.family: "Monospace"
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30"
                            border.color: Qt.darker("#555839", 1.2)
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: "#dde5a2"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: window.visible = false
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 56
                    color: Qt.rgba(0.18, 0.20, 0.17, 0.8)
                    radius: 8
                    border.color: "#555839"
                    border.width: 1

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        // Storage Information Line
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Text {
                                text: "Storage Total: " + storageTotal
                                color: "#b0ac63"
                                font.pixelSize: 11
                                font.family: "Monospace"
                                font.bold: true
                            }
                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 11
                                font.family: "Monospace"
                            }
                            Text {
                                text: "Used: " + storageUsed
                                color: "#dde5a2"
                                font.pixelSize: 11
                                font.family: "Monospace"
                            }
                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 11
                                font.family: "Monospace"
                            }
                            Text {
                                text: "Available: " + storageAvail
                                color: "#dde5a2"
                                font.pixelSize: 11
                                font.family: "Monospace"
                            }
                        }

                        // Phone Info Line
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 12

                            Text {
                                text: "Make: " + phoneManufacturer
                                color: "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "Model: " + phoneModel
                                color: "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "Android: " + phoneAndroid
                                color: "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                            Text {
                                text: "Serial: " + phoneSerial
                                color: "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }
                        }
                    }
                }
            }
        }

        Component {
            id: pkgDelegate
            Rectangle {
                id: delegateRect
                required property string displayName
                required property string rawPkg
                required property bool isInstalled
                required property bool originalState

                width: ListView.view.width
                height: 48
                color: mouseArea.containsMouse ? Qt.rgba(0.28, 0.30, 0.25, 0.7) : Qt.rgba(0.22, 0.24, 0.21, 0.5)
                radius: 6
                border.color: mouseArea.containsMouse ? "#b0ac63" : "#3a3c2c"
                border.width: 1

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 8

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Text {
                            text: displayName
                            color: "#b0ac63"
                            font.pixelSize: 14
                            font.family: "Monospace"
                            font.bold: true
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }

                        Text {
                            text: (isInstalled ? "Status: Active" : "Status: Uninstalled") + " (" + rawPkg + ")"
                            color: isInstalled ? "#d0d0d0" : "#e0c070"
                            font.pixelSize: 11
                            font.family: "Monospace"
                            opacity: isInstalled ? 0.65 : 1.0
                            elide: Text.ElideMiddle
                        }
                    }

                    Switch {
                        id: control
                        checked: isInstalled

                        indicator: Rectangle {
                            implicitWidth: 44
                            implicitHeight: 22
                            x: control.leftPadding
                            y: parent.height / 2 - height / 2
                            radius: 11
                            color: control.checked ? "#2a2c22" : "#1b1c1e"
                            border.color: control.checked ? "#b0ac63" : "#444"
                            border.width: 1

                            Rectangle {
                                x: control.checked ? parent.width - width - 2 : 2
                                y: 2
                                width: 18
                                height: 18
                                radius: 9
                                color: control.checked ? "#dde5a2" : "#666666"

                                Behavior on x {
                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                }
                            }
                        }

                        onToggled: {
                            let currentPkg = rawPkg;
                            let newState = control.checked;
                            let updateModel = function(model) {
                                for (let i = 0; i < model.count; i++) {
                                    let item = model.get(i);
                                    if (item && item.rawPkg === currentPkg) {
                                        model.setProperty(i, "isInstalled", newState);
                                        return true;
                                    }
                                }
                                return false;
                            };
                            if (!updateModel(googleAppsModel)) {
                                if (!updateModel(thirdPartyAppsModel)) {
                                    updateModel(searchResultsModel);
                                }
                            }
                            recalculateChanges();

                            if (newState) {
                                pendingPlayStorePkg = currentPkg;
                                playStoreConnectCheckProc.running = true;
                            }
                        }
                    }
                }
            }
        }

        Process {
            id: checkDepsProc
            command: ["which", "clamscan"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        depsInstalled = true;
                    } else {
                        depsInstalled = false;
                    }
                }
            }
        }

        Process {
            id: scanProc
            command: [
                "bash", "-c",
                "TMP_DIR=$(mktemp -d) && adb pull /sdcard/Download \"$TMP_DIR/Download\" >/dev/null 2>&1 && clamscan -r \"$TMP_DIR/Download\"; SCAN_RES=$?; rm -rf \"$TMP_DIR\"; exit $SCAN_RES"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    isScanning = false;
                    let output = text.trim();
                    let lines = output.split("\n");
                    let foundThreat = "";

                    for (let i = 0; i < lines.length; i++) {
                        if (lines[i].includes("FOUND")) {
                            let parts = lines[i].split(":");
                            if (parts.length > 0) {
                                let fullPath = parts[0].trim();
                                foundThreat = fullPath.substring(fullPath.lastIndexOf("/") + 1);
                                break;
                            }
                        }
                    }

                    if (foundThreat !== "") {
                        detectedInfectedFile = foundThreat;
                        scanStatusMessage = "Infected file found: " + foundThreat;
                    } else {
                        detectedInfectedFile = "";
                        scanStatusMessage = "it's clean";
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    isScanning = false;
                }
            }
        }

        Process {
            id: quarantineProc
            command: []
            stdout: StdioCollector {
                onStreamFinished: {
                    scanStatusMessage = "Quarantine successful: Removed " + detectedInfectedFile;
                    detectedInfectedFile = "";
                    sharedTabHelper.readDirectoryContents();
                }
            }
        }

        Process {
            id: searchPhoneProc
            property string queryTerm: ""
            command: ["bash", "-c", "adb shell pm list packages | sed 's/package://'"]

            stdout: StdioCollector {
                onStreamFinished: {
                    searchResultsModel.clear();
                    searchAttempted = true;
                    let lines = text.trim().split("\n");
                    let term = searchPhoneProc.queryTerm.toLowerCase();

                    for (let i = 0; i < lines.length; i++) {
                        let pkg = lines[i].trim();
                        if (pkg.length > 0) {
                            let cleanName = formatDisplayName(pkg);
                            if (pkg.toLowerCase().includes(term) || cleanName.toLowerCase().includes(term)) {
                                searchResultsModel.append({
                                    "displayName": cleanName,
                                    "rawPkg": pkg,
                                    "isInstalled": true,
                                    "originalState": true
                                });
                            }
                        }
                    }
                    sortModel(searchResultsModel);
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {}
            }
        }

        Process {
            id: installFDroidProc
            command: ["bash", "-c", "curl -L -o /tmp/fdroid.apk https://f-droid.org/F-Droid.apk && adb push /tmp/fdroid.apk /data/local/tmp/fdroid.apk && adb shell pm install -r /data/local/tmp/fdroid.apk && adb shell monkey -p org.fdroid.fdroid -c android.intent.category.LAUNCHER 1"]
            stdout: StdioCollector {
                onStreamFinished: runDiagnostics()
            }
            stderr: StdioCollector {
                onStreamFinished: {}
            }
        }

        Process {
            id: openFDroidProc
            command: ["adb", "shell", "monkey", "-p", "org.fdroid.fdroid", "-c", "android.intent.category.LAUNCHER", "1"]
            stdout: StdioCollector { onStreamFinished: {} }
            stderr: StdioCollector { onStreamFinished: {} }
        }

        Process {
            id: playStoreConnectCheckProc
            command: ["adb", "get-state"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "device") {
                        if (pendingPlayStorePkg !== "") {
                            playStoreOpenProc.command = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "market://details?id=" + pendingPlayStorePkg];
                            playStoreOpenProc.running = true;
                            pendingPlayStorePkg = "";
                        }
                    } else {
                        playStoreRetryTimer.restart();
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    playStoreRetryTimer.restart();
                }
            }
        }

        Timer {
            id: playStoreRetryTimer
            interval: 2000
            repeat: false
            onTriggered: {
                if (pendingPlayStorePkg !== "") {
                    playStoreConnectCheckProc.running = true;
                }
            }
        }

        Process {
            id: playStoreOpenProc
            command: []
            stdout: StdioCollector { onStreamFinished: {} }
            stderr: StdioCollector { onStreamFinished: {} }
        }

        Process {
            id: rebootRecoveryProc
            command: ["adb", "reboot", "recovery"]
            stdout: StdioCollector { onStreamFinished: {} }
            stderr: StdioCollector { onStreamFinished: {} }
        }

        Process {
            id: rebootBootloaderProc
            command: ["adb", "reboot", "download"]
            stdout: StdioCollector { onStreamFinished: {} }
            stderr: StdioCollector { onStreamFinished: {} }
        }

        Timer {
            id: scrcpyReconnectTimer
            interval: 3000
            repeat: false
            running: false
            onTriggered: {
                if (isPhoneVisible && !startScrcpyProc.running && !killScrcpyProc.running) {
                    startScrcpyProc.running = true;
                }
            }
        }

        Process {
            id: startScrcpyProc
            command: [
                "scrcpy",
                "--window-title=OSD_SCRCPY_EMBED",
                "--no-audio",
                "--max-size=800",
                "--max-fps=60",
                "--window-width=340",
                "--window-height=680",
                "--window-x=600",
                "--window-y=200",
                "--window-borderless",
                "--stay-awake"
            ]

            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        console.log("[SCRCPY STDOUT]: " + text.trim());
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        console.log("[SCRCPY STDERR]: " + text.trim());
                    }
                }
            }
            onExited: (code, status) => {
                if (isPhoneVisible && code !== 0) {
                    scrcpyReconnectTimer.start();
                } else if (code === 0) {
                    isPhoneVisible = false;
                }
            }
        }

        Process {
            id: killScrcpyProc
            command: ["pkill", "-f", "OSD_SCRCPY_EMBED"]
            onExited: (code, status) => {
                // Handled cleanly by button trigger
            }
        }

        Process {
            id: checkAdbProc
            command: ["which", "adb"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        startupRestartAdbProc.running = true;
                    } else {
                        showMissingAdbGuide();
                    }
                }
            }
        }

        Process {
            id: startupRestartAdbProc
            command: ["sh", "-c", "adb kill-server && adb start-server"]
            stdout: StdioCollector {
                onStreamFinished: {
                    checkDevicesProc.running = true;
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    checkDevicesProc.running = true;
                }
            }
        }

        Process {
            id: checkDevicesProc
            command: ["adb", "devices"]
            stdout: StdioCollector {
                onStreamFinished: parseAdbDevices(text)
            }
        }

        Process {
            id: fetchPhoneInfoManufacturer
            command: ["adb", "shell", "getprop", "ro.product.manufacturer"]
            stdout: StdioCollector {
                onStreamFinished: { phoneManufacturer = text.trim(); fetchPhoneInfoModel.running = true; }
            }
        }

        Process {
            id: fetchPhoneInfoModel
            command: ["adb", "shell", "getprop", "ro.product.model"]
            stdout: StdioCollector {
                onStreamFinished: { phoneModel = text.trim(); fetchPhoneInfoAndroid.running = true; }
            }
        }

        Process {
            id: fetchPhoneInfoAndroid
            command: ["adb", "shell", "getprop", "ro.build.version.release"]
            stdout: StdioCollector {
                onStreamFinished: { phoneAndroid = text.trim(); fetchPhoneInfoSerial.running = true; }
            }
        }

        Process {
            id: fetchPhoneInfoSerial
            command: ["adb", "get-serialno"]
            stdout: StdioCollector {
                onStreamFinished: { phoneSerial = text.trim(); fetchPhoneInfoStorage.running = true; }
            }
        }

        Process {
            id: fetchPhoneInfoStorage
            command: ["adb", "shell", "df", "-h", "/sdcard"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n");
                    if (lines.length > 1) {
                        let parts = lines[lines.length - 1].trim().split(/\s+/);
                        if (parts.length >= 4) {
                            storageTotal = parts[1];
                            storageUsed = parts[2];
                            storageAvail = parts[3];
                        }
                    }
                    fetchLaunchersProc.running = true;
                }
            }
        }

        Process {
            id: fetchLaunchersProc
            command: ["adb", "shell", "cmd", "package", "query-activities", "-a", "android.intent.action.MAIN", "-c", "android.intent.category.LAUNCHER"]
            stdout: StdioCollector {
                onStreamFinished: {
                    parseLaunchableApps(text);
                    fetchInstalledPackagesProc.running = true;
                }
            }
        }

        Process {
            id: fetchInstalledPackagesProc
            command: ["adb", "shell", "pm", "list", "packages"]
            stdout: StdioCollector {
                onStreamFinished: {
                    fetchUninstalledPackagesProc.installedRaw = text;
                    fetchUninstalledPackagesProc.running = true;
                }
            }
        }

        Process {
            id: fetchUninstalledPackagesProc
            property string installedRaw: ""
            command: ["adb", "shell", "pm", "list", "packages", "-u"]
            stdout: StdioCollector {
                onStreamFinished: {
                    finalizeAppLists(fetchUninstalledPackagesProc.installedRaw, text, {});
                }
            }
        }

        Process {
            id: fetchRawCommandOutputProc
            command: [
                "bash", "-c",
                "comm -13 <(adb shell pm list packages | sed 's/package://' | sort) <(adb shell pm list packages -u | sed 's/package://' | sort) | grep -vE '^(com\\.(google|samsung|sec|android|facebook|huawei)|vendor)'"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    let textOut = text.trim();
                    let lines = textOut.split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        let pkg = lines[i].replace("package:", "").trim();
                        if (pkg.length > 0 && !isSystemCritical(pkg)) {
                            let exists = false;
                            for (let j = 0; j < thirdPartyAppsModel.count; j++) {
                                if (thirdPartyAppsModel.get(j).rawPkg === pkg) {
                                    exists = true;
                                    break;
                                }
                            }
                            if (!exists) {
                                thirdPartyAppsModel.append({
                                    "displayName": formatDisplayName(pkg),
                                                           "rawPkg": pkg,
                                                           "isInstalled": false,
                                                           "originalState": false
                                });
                            }
                        }
                    }
                    sortModel(thirdPartyAppsModel);
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {}
            }
        }

        Process {
            id: restartAdbProc
            command: ["sh", "-c", "adb kill-server && adb start-server"]
            stdout: StdioCollector {
                onStreamFinished: checkDevicesProc.running = true
            }
        }

        Process {
            id: actionProc
            property string currentPkg: ""
            property bool isFallbackMode: false

            stdout: StdioCollector {
                onStreamFinished: {
                    let out = text.trim();
                    if (out.length > 0) {
                        statusText.text += "  -> Output: " + out + "\n";
                    }

                    if (!actionProc.isFallbackMode && out.includes("NameNotFoundException")) {
                        statusText.text += "⚠️ Package completely wiped. Opening Play Store page on phone...\n";
                        actionProc.isFallbackMode = true;
                        actionProc.command = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "market://details?id=" + actionProc.currentPkg];
                        actionProc.running = true;
                        return;
                    }

                    actionProc.isFallbackMode = false;
                    processNextAction();
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    let err = text.trim();
                    if (err.length > 0) {
                        statusText.text += "  [ERROR]: " + err + "\n";
                    }
                }
            }
        }

        Timer {
            id: statusScrollView
            property bool visible: true
        }

        Timer {
            interval: 80
            running: true
            repeat: false
            onTriggered: {
                checkDepsProc.running = true;
                runDiagnostics();
            }
        }
    }

    function triggerPhoneSearch() {
        let term = searchField.text.trim();
        if (term.length > 0) {
            searchPhoneProc.queryTerm = term;
            searchPhoneProc.running = true;
        } else {
            searchAttempted = false;
            searchResultsModel.clear();
        }
    }

    function runDiagnostics() {
        statusScrollView.visible = true;
        statusText.text = "Checking Linux dependencies & restarting ADB daemon...\n";
        checkAdbProc.running = true;
    }

    function showMissingAdbGuide() {
        statusText.text =
        "⚠️ ADB IS NOT INSTALLED\n\n" +
        "Please install android-tools & scrcpy via your package manager.\n\n" +
        "Steps:\n1. Run package manager install.\n2. Connect phone.\n3. Re-check Devices.";
    }

    function parseAdbDevices(output) {
        let lines = output.trim().split("\n");
        let deviceFound = false;
        let unauthorized = false;

        for (let i = 1; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line.length > 0) {
                deviceFound = true;
                if (line.includes("unauthorized")) unauthorized = true;
            }
        }

        if (!deviceFound) {
            statusText.text =
            "⚠️ NO DEVICE FOUND\n\n" +
            "1. Connect phone via USB.\n" +
            "2. Turn on 'USB Debugging'.\n" +
            "3. Click 'Re-check Devices'.";
        } else if (unauthorized) {
            statusText.text = "⚠️ DEVICE UNAUTHORIZED\n\nAccept USB debugging prompt on your phone screen...";
            restartAdbProc.running = true;
        } else {
            statusText.text = "Device authorized! Querying phone info and app records...\n";
            fetchPhoneInfoManufacturer.running = true;
        }
    }

    function parseLaunchableApps(output) {
        let lines = output.split("\n");
        let apps = [];
        for (let i = 0; i < lines.length; i++) {
            let line = lines[i].trim();
            if (line.includes("packageName=")) {
                let pkg = line.split("packageName=")[1].split(" ")[0].trim();
                if (pkg.length > 0 && apps.indexOf(pkg) === -1) {
                    apps.push(pkg);
                }
            }
        }
        launchableApps = apps;
    }

    function finalizeAppLists(installedText, uninstalledText, trackedMap) {
        googleAppsModel.clear();
        thirdPartyAppsModel.clear();
        appsToUninstall = [];
        appsToEnable = [];

        let parsePackages = function(rawText) {
            let list = [];
            let lines = rawText.split("\n");
            for (let i = 0; i < lines.length; i++) {
                let pkg = lines[i].replace("package:", "").trim();
                if (pkg.length > 0 && list.indexOf(pkg) === -1) {
                    list.push(pkg);
                }
            }
            return list;
        };

        let activeList = parsePackages(installedText);
        let allList = parsePackages(uninstalledText);

        isFDroidInstalled = activeList.indexOf("org.fdroid.fdroid") !== -1;

        let combinedMap = {};
        for (let i = 0; i < allList.length; i++) {
            let pkg = allList[i];
            let isActive = activeList.indexOf(pkg) !== -1;
            combinedMap[pkg] = isActive;
        }

        for (let pkg in trackedMap) {
            if (trackedMap[pkg]) {
                combinedMap[pkg] = false;
            } else if (combinedMap[pkg] === undefined) {
                combinedMap[pkg] = true;
            }
        }

        let explicitCheckList = ["com.google.android.apps.photos", "com.google.ar.lens"];
        for (let i = 0; i < explicitCheckList.length; i++) {
            let pkg = explicitCheckList[i];
            if (combinedMap[pkg] === undefined) {
                combinedMap[pkg] = false;
            }
        }

        let sortedPkgs = Object.keys(combinedMap).sort(function(a, b) {
            let activeA = combinedMap[a];
            let activeB = combinedMap[b];
            let isGoogleA = a.toLowerCase().includes("google") || a === "com.android.chrome";
            let isGoogleB = b.toLowerCase().includes("google") || b === "com.android.chrome";

            if (!isGoogleA && !isGoogleB) {
                if (activeA !== activeB) return activeA ? -1 : 1;
            }

            if (activeA === activeB) return a.localeCompare(b);
            return activeA ? -1 : 1;
        });

        for (let i = 0; i < sortedPkgs.length; i++) {
            let rawPkg = sortedPkgs[i];
            let isActive = combinedMap[rawPkg];

            if (isSystemCritical(rawPkg)) {
                continue;
            }

            let isGoogle = rawPkg.toLowerCase().includes("google") || rawPkg === "com.android.chrome";
            let isLaunchable = launchableApps.indexOf(rawPkg) !== -1 || explicitCheckList.indexOf(rawPkg) !== -1;

            if (!isGoogle && !isLaunchable && trackedMap[rawPkg] === undefined) {
                continue;
            }

            let cleanName = formatDisplayName(rawPkg);
            let itemData = {
                "displayName": cleanName,
                "rawPkg": rawPkg,
                "isInstalled": isActive,
                "originalState": isActive
            };

            if (isGoogle) {
                googleAppsModel.append(itemData);
            } else {
                thirdPartyAppsModel.append(itemData);
            }
        }
        statusScrollView.visible = false;
        recalculateChanges();

        fetchRawCommandOutputProc.running = true;
    }

    function applyPendingChanges() {
        statusScrollView.visible = true;
        statusText.text = "Applying pending package changes...\n\n";
        processNextAction();
    }

    function markItemLocally(pkg, isInstalledState) {
        let updateModel = function(model) {
            for (let i = 0; i < model.count; i++) {
                let item = model.get(i);
                if (item && item.rawPkg === pkg) {
                    model.setProperty(i, "isInstalled", isInstalledState);
                    model.setProperty(i, "originalState", isInstalledState);
                    return true;
                }
            }
            return false;
        };

        let found = updateModel(googleAppsModel);
        if (!found) {
            found = updateModel(thirdPartyAppsModel);
        }
        if (!found) {
            found = updateModel(searchResultsModel);
        }

        if (found) {
            sortModel(googleAppsModel);
            sortModel(thirdPartyAppsModel);
            sortModel(searchResultsModel);
        }
    }

    function processNextAction() {
        let uninstalls = appsToUninstall;
        let enables = appsToEnable;

        if (uninstalls.length > 0) {
            let pkg = uninstalls.shift();
            appsToUninstall = uninstalls;
            actionProc.currentPkg = pkg;
            actionProc.isFallbackMode = false;
            statusText.text += "Uninstalling " + pkg + "...\n";

            markItemLocally(pkg, false);

            actionProc.command = ["adb", "shell", "pm", "uninstall", "-k", "--user", "0", pkg];
            actionProc.running = true;
        } else if (enables.length > 0) {
            let pkg = enables.shift();
            appsToEnable = enables;
            actionProc.currentPkg = pkg;
            actionProc.isFallbackMode = false;
            statusText.text += "Restoring " + pkg + "...\n";

            markItemLocally(pkg, true);

            actionProc.command = ["adb", "shell", "cmd", "package", "install-existing", pkg];
            actionProc.running = true;
        } else {
            statusText.text += "\nCompleted! Refreshing state...";
            runDiagnostics();
        }
    }
}
