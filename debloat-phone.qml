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
    property string phoneReleaseYear: "-"
    property string phoneBuildDate: "-"

    // Battery & System Update Properties
    property string phoneBatteryLevel: "-"
    property bool isUpdateAvailable: false

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

    // Selected app info (description now fetched via Gemini on click)
    property var selectedAppInfo: null

    // Gemini API key – loaded at runtime from a local file (never hard-coded)
    // Looked up in this order:
    //   1. ~/.config/debloat-phone/gemini.key
    //   2. gemini.key next to this QML file
    property string geminiApiKey: ""
    property bool geminiKeyLoaded: false

    // Dynamically discovered free Gemini models (populated at runtime)
    property string geminiModel: ""                  // currently preferred model
    property var geminiModelCandidates: ([])         // ordered list of fallback models
    property int geminiModelIndex: 0                 // index into candidates for current attempt
    property bool geminiModelsQueried: false
    property var pendingGeminiPkg: ""                // package waiting while we discover models

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

    Component.onCompleted: {
        loadGeminiKeyProc.running = true;   // load API key from local file first
        runDiagnostics();
    }

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

    function triggerPhoneSearch() {
        let query = searchField.text.trim();
        if (query.length === 0) return;
        searchAttempted = true;
        searchResultsModel.clear();
        searchPhoneProc.queryTerm = query.toLowerCase();
        searchPhoneProc.running = true;
    }

    function applyPendingChanges() {
        pendingActionsQueue = [];
        for (let i = 0; i < appsToUninstall.length; i++) {
            pendingActionsQueue.push({ type: "uninstall", pkg: appsToUninstall[i] });
        }
        for (let i = 0; i < appsToEnable.length; i++) {
            pendingActionsQueue.push({ type: "enable", pkg: appsToEnable[i] });
        }

        statusScrollView.visible = true;
        statusText.text = "Starting package state updates...\n";
        processNextAction();
    }

    function processNextAction() {
        if (pendingActionsQueue.length === 0) {
            statusText.text += "\nFinished applying changes. Refreshing package list...\n";
            runDiagnostics();
            return;
        }

        let action = pendingActionsQueue.shift();
        actionProc.currentPkg = action.pkg;
        actionProc.isFallbackMode = false;

        if (action.type === "uninstall") {
            statusText.text += "Uninstalling " + action.pkg + "...\n";
            actionProc.command = ["adb", "shell", "pm", "uninstall", "-k", "--user", "0", action.pkg];
        } else if (action.type === "enable") {
            statusText.text += "Enabling/Installing " + action.pkg + "...\n";
            actionProc.command = ["adb", "shell", "cmd", "package", "install-existing", action.pkg];
        }
        actionProc.running = true;
    }

    function runDiagnostics() {
        checkDepsProc.running = true;
        fetchBatteryProc.running = true;
        checkUpdateProc.running = true;
        fetchDeviceInfoProc.running = true;
        fetchStorageProc.running = true;
        fetchThirdPartyAppsProc.running = true;
        fetchGoogleAppsProc.running = true;
    }

    property var pendingActionsQueue: []

    QtObject {
        id: statusScrollView
        property bool visible: false
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

            Image {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.topMargin: 200

                width: parent.width * 1.1
                height: parent.height
                source: "setele.png"
                opacity: 0.4
                fillMode: Image.PreserveAspectFit
                layer.enabled: true
            }

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

                    // Top-right exit (X) button to close the OSD window
                    Button {
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        width: 36
                        height: 36
                        text: "✕"
                        font.pixelSize: 18
                        font.bold: true
                        scale: pressed ? 0.92 : 1.0
                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.pressed || parent.hovered ? "#5a2d2d" : "transparent"
                            border.color: parent.pressed || parent.hovered ? "#d9534f" : "transparent"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: parent.pressed || parent.hovered ? "#ffaaaa" : "#b0ac63"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: window.visible = false
                    }
                }

                TabBar {
                    id: tabBar
                    Layout.fillWidth: true
                    spacing: 2
                    background: Rectangle { color: "transparent" }

                    onCurrentIndexChanged: {
                        selectedAppInfo = null; // Reset selection on tab change
                        if (currentIndex === 2) {
                            searchField.forceActiveFocus();
                        } else if (currentIndex === 4) {
                            sharedTabHelper.onTabSelected();
                        } else if (currentIndex === 5) {
                            monitoringTabHelper.onTabSelected();
                        } else if (currentIndex === 6) {
                            secureTabHelper.checkTelemetry();
                            secureTabHelper.fetchBatteryOptimization();
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

                    TabButton {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 38
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        contentItem: Text {
                            text: "Secure\nPhone"
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
                                        placeholderText: "Search… (try: services, google apps, third party)"
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
                                                            adbPullProc.command = ["adb", "pull", remoteSharedFolder + "/" + fName, Qt.resolvedUrl("~/Downloads").toString().replace("file://", "")];
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

                        // Secure Phone Tab View
                        Item {
                            id: secureTabHelper

                            ListModel {
                                id: secureTelemetryModel
                            }

                            ListModel {
                                id: batteryOptimizationModel
                            }

                            property bool isChecking: false
                            property bool isBatteryChecking: false
                            property bool isNuking: false
                            property string nukeStatus: ""

                            function fetchBatteryOptimization() {
                                batteryOptimizationModel.clear();
                                isBatteryChecking = true;
                                console.log("[BATTERY OPT]: Executing query for un-optimized background packages...");
                                fetchBatteryOptProc.running = true;
                            }

                            function checkTelemetry() {
                                secureTelemetryModel.clear();
                                isChecking = true;
                                console.log("[TELEMETRY SCAN]: Starting full ADB system scan for active telemetry settings...");
                                auditTelemetryProc.running = true;
                            }

                            function startNukePhone() {
                                if (isNuking) return;
                                isNuking = true;
                                nukeStatus = "Starting Nuke Phone sequence...\n";
                                nukePhoneProc.running = true;
                            }

                            Process {
                                id: nukePhoneProc
                                command: [
                                    "bash", "-c",
                                    "echo '=== 1. Disabling window animations ==='; " +
                                    "adb shell settings put global window_animation_scale 0.0; " +
                                    "adb shell settings put global transition_animation_scale 0.0; " +
                                    "adb shell settings put global animator_duration_scale 0.0; " +
                                    "echo -n 'window_animation_scale = '; adb shell settings get global window_animation_scale; " +
                                    "echo -n 'transition_animation_scale = '; adb shell settings get global transition_animation_scale; " +
                                    "echo -n 'animator_duration_scale = '; adb shell settings get global animator_duration_scale; " +
                                    "echo; " +
                                    "echo '=== 2. Force GPU Rendering & Disable Hardware Overlays ==='; " +
                                    "adb shell setprop debug.composition.type gpu; " +
                                    "adb shell service call SurfaceFlinger 1008 i32 1; " +
                                    "echo; " +
                                    "echo '=== 3. Cap Background Processes at 2 ==='; " +
                                    "adb shell settings put global max_phantom_processes 2; " +
                                    "adb shell device_config put activity_manager max_phantom_processes 2; " +
                                    "echo; " +
                                    "echo '=== 4. Turn Off Adaptive Battery ==='; " +
                                    "adb shell settings put global adaptive_battery_management_enabled 0; " +
                                    "echo; " +
                                    "echo '=== 5. Kill Location Services & Scanning Radios ==='; " +
                                    "adb shell settings put secure location_mode 0; " +
                                    "adb shell settings put global wifi_scan_always_enabled 0; " +
                                    "adb shell settings put global ble_scan_always_enabled 0; " +
                                    "echo; " +
                                    "echo '=== 6. Trimming app caches (global) ==='; " +
                                    "adb shell pm trim-caches 1000G; " +
                                    "echo 'Global cache trim requested.'; " +
                                    "echo; " +
                                    "echo '=== 7. Clearing third-party package caches ==='; " +
                                    "for pkg in $(adb shell pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\\r'); do " +
                                    "  echo \"Clearing cache for: $pkg\"; " +
                                    "  adb shell pm clear --cache-only $pkg 2>/dev/null || adb shell cmd package compile -m speed-profile -f $pkg >/dev/null 2>&1 || true; " +
                                    "done; " +
                                    "echo; " +
                                    "echo '=== 8. Force-stopping third-party apps ==='; " +
                                    "for pkg in $(adb shell pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\\r'); do " +
                                    "  echo \"Force-stopping: $pkg\"; " +
                                    "  adb shell am force-stop $pkg 2>/dev/null || true; " +
                                    "done; " +
                                    "echo; " +
                                    "echo '=== 9. Disabling Samsung & Microsoft bloat ==='; " +
                                    "for pkg in " +
                                    "com.samsung.android.app.watchmanager " +
                                    "com.samsung.android.app.watchmanagerstub " +
                                    "com.samsung.android.bixby.agent " +
                                    "com.samsung.android.bixby.agent.dummy " +
                                    "com.samsung.android.bixby.wakeup " +
                                    "com.samsung.android.app.spage " +
                                    "com.samsung.android.ardrawing " +
                                    "com.samsung.android.aremoji " +
                                    "com.samsung.android.arzone " +
                                    "com.samsung.android.beaconmanager " +
                                    "com.samsung.android.da.daassistant " +
                                    "com.samsung.android.game.gamehome " +
                                    "com.samsung.android.game.gametools " +
                                    "com.samsung.android.game.gos " +
                                    "com.samsung.android.galaxyfinder " +
                                    "com.samsung.android.themestore " +
                                    "com.samsung.android.themecenter " +
                                    "com.samsung.android.kidsinstaller " +
                                    "com.samsung.android.app.tips " +
                                    "com.samsung.android.lool " +
                                    "com.samsung.android.sm.devicesecurity " +
                                    "com.samsung.android.forest " +
                                    "com.samsung.android.fmm " +
                                    "com.samsung.android.app.routines " +
                                    "com.samsung.android.rubin.app " +
                                    "com.samsung.android.voc " +
                                    "com.samsung.android.calendar " +
                                    "com.samsung.android.app.contacts " +
                                    "com.samsung.android.messaging " +
                                    "com.samsung.android.app.notes " +
                                    "com.samsung.android.app.reminder " +
                                    "com.samsung.android.email.provider " +
                                    "com.samsung.android.scloud " +
                                    "com.samsung.android.oneconnect " +
                                    "com.samsung.android.samsungpass " +
                                    "com.samsung.android.samsungpassautofill " +
                                    "com.samsung.android.authfw " +
                                    "com.samsung.android.spay " +
                                    "com.samsung.android.spayfw " +
                                    "com.samsung.android.knox.containeragent " +
                                    "com.samsung.android.knox.containercore " +
                                    "com.samsung.android.mdm " +
                                    "com.samsung.android.smartmirroring " +
                                    "com.samsung.android.smartswitchassistant " +
                                    "com.sec.android.app.samsungapps " +
                                    "com.sec.android.app.sbrowser " +
                                    "com.sec.android.app.popupcalculator " +
                                    "com.sec.android.daemonapp " +
                                    "com.sec.android.easyonehand " +
                                    "com.sec.android.easyMover " +
                                    "com.sec.android.easyMover.Agent " +
                                    "com.sec.android.widgetapp.samsungapps " +
                                    "com.microsoft.skydrive " +
                                    "com.microsoft.appmanager " +
                                    "com.microsoft.office.officehubrow " +
                                    "com.microsoft.office.outlook " +
                                    "com.microsoft.office.excel " +
                                    "com.microsoft.office.word " +
                                    "com.microsoft.office.powerpoint " +
                                    "com.microsoft.office.onenote " +
                                    "com.skype.raider " +
                                    "com.linkedin.android " +
                                    "com.samsung.android.app.clipboardedge " +
                                    "com.samsung.android.app.dressroom " +
                                    "com.samsung.android.app.ledbackcover " +
                                    "com.samsung.android.app.mirrorlink " +
                                    "com.samsung.android.app.simplesharing " +
                                    "com.samsung.android.app.social " +
                                    "com.samsung.android.app.taskedge " +
                                    "com.samsung.android.mateagent " +
                                    "com.samsung.android.stickercenter " +
                                    "com.samsung.android.svcagent " +
                                    "com.samsung.android.svoiceime " +
                                    "com.samsung.android.visionintelligence " +
                                    "com.samsung.android.ipsgeofence " +
                                    "com.samsung.android.location " +
                                    "com.samsung.android.mapsagent " +
                                    "com.samsung.android.networkdiagnostic " +
                                    "com.samsung.android.networkstack " +
                                    "com.samsung.android.privateshare " +
                                    "com.samsung.android.smartcallprovider " +
                                    "com.samsung.android.smartface " +
                                    "com.samsung.android.smartfitting " +
                                    "com.samsung.android.smartscroll " +
                                    "com.samsung.crane " +
                                    "com.samsung.faceservice " +
                                    "com.samsung.ipservice " +
                                    "com.samsung.klmsagent " +
                                    "com.samsung.oh " +
                                    "com.samsung.rcs " +
                                    "com.samsung.storyservice " +
                                    "com.wsomacp " +
                                    "com.wssyncmldm " +
                                    "; do " +
                                    "  if adb shell pm path $pkg >/dev/null 2>&1; then " +
                                    "    echo \"Disabling: $pkg\"; " +
                                    "    adb shell pm disable-user --user 0 $pkg 2>/dev/null || adb shell pm uninstall -k --user 0 $pkg 2>/dev/null || true; " +
                                    "  fi; " +
                                    "done; " +
                                    "echo; " +
                                    "echo '=== Nuke Phone sequence finished ==='"
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        secureTabHelper.nukeStatus += text;
                                        secureTabHelper.isNuking = false;
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length > 0) {
                                            secureTabHelper.nukeStatus += "\n[stderr]\n" + text;
                                        }
                                        secureTabHelper.isNuking = false;
                                    }
                                }
                                onExited: (code) => {
                                    secureTabHelper.isNuking = false;
                                    if (code === 0) {
                                        secureTabHelper.nukeStatus += "\nCompleted successfully.";
                                    } else {
                                        secureTabHelper.nukeStatus += "\nFinished with exit code " + code;
                                    }
                                }
                            }

                            Process {
                                id: auditTelemetryProc
                                command: [
                                    "bash", "-c",
                                    "for item in " +
                                    "'App Crash Analytics|system|send_action_app_error|0' " +
                                    "'Security Diagnostics|system|send_security_reports|0' " +
                                    "'Samsung Diagnostic Agreement|system|samsung_errorlog_agree|0' " +
                                    "'Personalization Service API|global|settings_use_psd_api|0' " +
                                    "'External Provider Analytics|global|settings_use_external_provider_api|0' " +
                                    "'Network Recommendation Scoring|global|network_recommendations_enabled|0' " +
                                    "'Ad ID Tracking & Profiling|global|limit_ad_tracking|1' " +
                                    "'Diagnostic Log Auto-Upload|system|upload_debug_log|0' " +
                                    "'Package Usage Telemetry|secure|package_verifier_include_device_data|0' " +
                                    "'User Feedback Logging|system|user_full_report|0'; do " +
                                    "  IFS='|' read -r name ns key disable_target <<< \"$item\"; " +
                                    "  val=$(adb shell settings get $ns $key 2>/dev/null | tr -d '\r'); " +
                                    "  if [ -n \"$val\" ] && [ \"$val\" != \"null\" ] && [ \"$val\" != \"$disable_target\" ]; then " +
                                    "    echo \"$name|$ns|$key|$val|$disable_target\"; " +
                                    "  fi; " +
                                    "done"
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        secureTelemetryModel.clear();
                                        secureTabHelper.isChecking = false;
                                        let lines = text.trim().split("\n");
                                        let foundCount = 0;

                                        for (let i = 0; i < lines.length; i++) {
                                            let line = lines[i].trim();
                                            if (line.length > 0) {
                                                let parts = line.split("|");
                                                if (parts.length === 5) {
                                                    foundCount++;
                                                    console.log("[TELEMETRY SCAN RESULT]: Active telemetry -> " + parts[0] + " [" + parts[1] + "/" + parts[2] + " = " + parts[3] + "]");
                                                    secureTelemetryModel.append({
                                                        title: parts[0],
                                                        namespace: parts[1],
                                                        key: parts[2],
                                                        targetVal: parts[4],
                                                        isEnabled: true
                                                    });
                                                }
                                            }
                                        }

                                        if (foundCount > 0) {
                                            console.log("[TELEMETRY SCAN COMPLETE]: Found " + foundCount + " active telemetry items.");
                                        } else {
                                            console.log("[TELEMETRY SCAN COMPLETE]: Device is secure. No active safe-to-disable telemetry found.");
                                        }
                                    }
                                }

                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        secureTabHelper.isChecking = false;
                                        if (text.trim().length > 0) {
                                            console.log("[TELEMETRY ERROR]: " + text.trim());
                                        }
                                    }
                                }
                            }

                            Process {
                                id: disableTelemetryProc
                                property string disableKey: ""
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        console.log("[TELEMETRY DISABLE SUCCESS]: Updated key " + disableTelemetryProc.disableKey);
                                        for (let i = 0; i < secureTelemetryModel.count; i++) {
                                            if (secureTelemetryModel.get(i).key === disableTelemetryProc.disableKey) {
                                                secureTelemetryModel.remove(i);
                                                break;
                                            }
                                        }
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length > 0) {
                                            console.log("[TELEMETRY DISABLE ERROR]: " + text.trim());
                                        }
                                    }
                                }
                            }

                            Process {
                                id: fetchBatteryOptProc
                                command: [
                                    "bash", "-c",
                                    "for pkg in $(comm -23 <(adb shell pm list packages -3 | sed 's/package://' | sort) <(adb shell dumpsys deviceidle whitelist | grep -oE '[a-zA-Z0-9_.]+' | sort -u)); do " +
                                    "  bucket=$(adb shell am get-standby-bucket $pkg | tr -d '\r'); " +
                                    "  op1=$(adb shell appops get $pkg RUN_IN_BACKGROUND 2>/dev/null | grep -iE 'ignore|deny|restricted' || true); " +
                                    "  op2=$(adb shell appops get $pkg RUN_ANY_IN_BACKGROUND 2>/dev/null | grep -iE 'ignore|deny|restricted' || true); " +
                                    "  if [ \"$bucket\" != \"restricted\" ] && [ -z \"$op1\" ] && [ -z \"$op2\" ]; then " +
                                    "    echo $pkg; " +
                                    "  fi; " +
                                    "done"
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        batteryOptimizationModel.clear();
                                        secureTabHelper.isBatteryChecking = false;
                                        let lines = text.trim().split("\n");

                                        for (let i = 0; i < lines.length; i++) {
                                            let rawPkg = lines[i].trim();
                                            if (rawPkg.length > 0 && !isSystemCritical(rawPkg)) {
                                                batteryOptimizationModel.append({
                                                    displayName: formatDisplayName(rawPkg),
                                                                                rawPkg: rawPkg,
                                                                                isToggledOn: true
                                                });
                                            }
                                        }
                                        console.log("[BATTERY OPT COMPLETE]: Discovered " + batteryOptimizationModel.count + " un-restricted background packages.");
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        secureTabHelper.isBatteryChecking = false;
                                        if (text.trim().length > 0) {
                                            console.log("[BATTERY OPT ERROR]: " + text.trim());
                                        }
                                    }
                                }
                            }

                            Process {
                                id: restrictBatteryProc
                                property var cmdQueue: []

                                function runNext() {
                                    if (cmdQueue.length > 0) {
                                        let nextCmd = cmdQueue.shift();
                                        console.log("[BATTERY PROC EXEC]: " + nextCmd.join(" "));
                                        command = nextCmd;
                                        running = true;
                                    }
                                }

                                onExited: (code, status) => {
                                    if (code === 0) {
                                        console.log("[BATTERY PROC SUCCESS]: Step executed successfully.");
                                    } else {
                                        console.log("[BATTERY PROC ERROR]: Exit code " + code);
                                    }
                                    runNext();
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 4
                                spacing: 10

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Active Telemetry Settings"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }

                                    Button {
                                        width: 90
                                        height: 28
                                        text: "Rescan"
                                        font.pixelSize: 11
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

                                        onClicked: secureTabHelper.checkTelemetry()
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 85

                                    ScrollView {
                                        anchors.fill: parent
                                        visible: secureTelemetryModel.count > 0
                                        clip: true

                                        ListView {
                                            anchors.fill: parent
                                            model: secureTelemetryModel
                                            spacing: 6

                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 44
                                                color: Qt.rgba(0.22, 0.24, 0.21, 0.5)
                                                radius: 6
                                                border.color: "#3a3c2c"
                                                border.width: 1

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.margins: 8

                                                    ColumnLayout {
                                                        anchors.left: parent.left
                                                        anchors.right: telemetrySwitch.left
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        Text {
                                                            text: model.title
                                                            color: "#b0ac63"
                                                            font.pixelSize: 12
                                                            font.family: "Monospace"
                                                            font.bold: true
                                                            elide: Text.ElideMiddle
                                                            Layout.fillWidth: true
                                                        }

                                                        Text {
                                                            text: model.namespace + " / " + model.key
                                                            color: "#dde5a2"
                                                            font.pixelSize: 10
                                                            font.family: "Monospace"
                                                            opacity: 0.8
                                                            elide: Text.ElideMiddle
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Switch {
                                                        id: telemetrySwitch
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        checked: model.isEnabled

                                                        indicator: Rectangle {
                                                            implicitWidth: 44
                                                            implicitHeight: 22
                                                            radius: 11
                                                            color: telemetrySwitch.checked ? "#2a2c22" : "#1b1c1e"
                                                            border.color: telemetrySwitch.checked ? "#b0ac63" : "#444"
                                                            border.width: 1

                                                            Rectangle {
                                                                x: telemetrySwitch.checked ? parent.width - width - 2 : 2
                                                                y: 2
                                                                width: 18
                                                                height: 18
                                                                radius: 9
                                                                color: telemetrySwitch.checked ? "#dde5a2" : "#666666"

                                                                Behavior on x {
                                                                    NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                                                }
                                                            }
                                                        }

                                                        onToggled: {
                                                            if (!telemetrySwitch.checked) {
                                                                disableTelemetryProc.disableKey = model.key;
                                                                let target = model.targetVal || "0";
                                                                console.log("[TELEMETRY DISABLE TRIGGERED]: Disabling " + model.key + " -> setting target " + target);
                                                                disableTelemetryProc.command = ["adb", "shell", "settings", "put", model.namespace, model.key, target];
                                                                disableTelemetryProc.running = true;
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        anchors.centerIn: parent
                                        visible: secureTelemetryModel.count === 0 && !secureTabHelper.isChecking
                                        spacing: 8

                                        Text {
                                            text: "🛡"
                                            font.pixelSize: 32
                                            Layout.alignment: Qt.AlignHCenter
                                        }

                                        Text {
                                            text: "Phone is secure! No active safe-to-disable telemetry items detected."
                                            color: "#dde5a2"
                                            font.pixelSize: 13
                                            font.family: "Monospace"
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: secureTabHelper.isChecking
                                        text: "Auditing phone telemetry settings..."
                                        color: "#b0ac63"
                                        font.pixelSize: 13
                                        font.family: "Monospace"
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 100
                                    spacing: 6

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Text {
                                            text: "Battery Optimization    <font color='#cd4f4c'>-Put apps in deep sleep mode</font>"
                                            color: "#dde5a2"
                                            font.bold: true
                                            font.family: "Monospace"
                                            font.pixelSize: 13
                                            Layout.fillWidth: true
                                        }

                                        Button {
                                            width: 90
                                            height: 28
                                            text: "Refresh"
                                            font.pixelSize: 11
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

                                            onClicked: secureTabHelper.fetchBatteryOptimization()
                                        }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#1a1c18"
                                        radius: 8
                                        border.color: "#555839"
                                        border.width: 1

                                        ScrollView {
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            visible: batteryOptimizationModel.count > 0
                                            clip: true

                                            ListView {
                                                anchors.fill: parent
                                                model: batteryOptimizationModel
                                                spacing: 6

                                                delegate: Rectangle {
                                                    width: ListView.view.width
                                                    height: 48
                                                    color: Qt.rgba(0.22, 0.24, 0.21, 0.5)
                                                    radius: 6
                                                    border.color: "#3a3c2c"
                                                    border.width: 1

                                                    Item {
                                                        anchors.fill: parent
                                                        anchors.margins: 8

                                                        ColumnLayout {
                                                            anchors.left: parent.left
                                                            anchors.right: batterySwitch.left
                                                            anchors.rightMargin: 8
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            spacing: 2

                                                            Text {
                                                                text: model.displayName
                                                                color: "#b0ac63"
                                                                font.pixelSize: 12
                                                                font.family: "Monospace"
                                                                font.bold: true
                                                                elide: Text.ElideMiddle
                                                                Layout.fillWidth: true
                                                            }

                                                            Text {
                                                                text: model.rawPkg
                                                                color: "#dde5a2"
                                                                font.pixelSize: 11
                                                                font.family: "Monospace"
                                                                opacity: 0.8
                                                                elide: Text.ElideMiddle
                                                                Layout.fillWidth: true
                                                            }
                                                        }

                                                        Switch {
                                                            id: batterySwitch
                                                            anchors.right: parent.right
                                                            anchors.verticalCenter: parent.verticalCenter
                                                            checked: model.isToggledOn

                                                            indicator: Rectangle {
                                                                implicitWidth: 44
                                                                implicitHeight: 22
                                                                radius: 11
                                                                color: batterySwitch.checked ? "#2a2c22" : "#1b1c1e"
                                                                border.color: batterySwitch.checked ? "#b0ac63" : "#444"
                                                                border.width: 1

                                                                Rectangle {
                                                                    x: batterySwitch.checked ? parent.width - width - 2 : 2
                                                                    y: 2
                                                                    width: 18
                                                                    height: 18
                                                                    radius: 9
                                                                    color: batterySwitch.checked ? "#dde5a2" : "#666666"

                                                                    Behavior on x {
                                                                        NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                                                                    }
                                                                }
                                                            }

                                                            onToggled: {
                                                                model.isToggledOn = batterySwitch.checked;
                                                                let pkg = model.rawPkg;

                                                                if (!batterySwitch.checked) {
                                                                    restrictBatteryProc.cmdQueue = [
                                                                        ["adb", "shell", "am", "set-standby-bucket", pkg, "restricted"],
                                                                        ["adb", "shell", "appops", "set", pkg, "RUN_IN_BACKGROUND", "ignore"],
                                                                        ["adb", "shell", "appops", "set", pkg, "RUN_ANY_IN_BACKGROUND", "ignore"]
                                                                    ];
                                                                } else {
                                                                    restrictBatteryProc.cmdQueue = [
                                                                        ["adb", "shell", "am", "set-standby-bucket", pkg, "working_set"],
                                                                        ["adb", "shell", "appops", "set", pkg, "RUN_IN_BACKGROUND", "allow"],
                                                                        ["adb", "shell", "appops", "set", pkg, "RUN_ANY_IN_BACKGROUND", "allow"]
                                                                    ];
                                                                }
                                                                restrictBatteryProc.runNext();
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: batteryOptimizationModel.count === 0 && !secureTabHelper.isBatteryChecking
                                            text: "No safe third-party apps available to restrict."
                                            color: "#b0ac63"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            visible: secureTabHelper.isBatteryChecking
                                            text: "Fetching battery optimization statistics..."
                                            color: "#b0ac63"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                        }
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    spacing: 10

                                    Text {
                                        text: "Nuke Phone Output"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        color: "#1a1c18"
                                        radius: 8
                                        border.color: "#555839"
                                        border.width: 1

                                        ScrollView {
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            clip: true

                                            TextArea {
                                                id: nukeStatusArea
                                                readOnly: true
                                                text: secureTabHelper.nukeStatus.length > 0 ? secureTabHelper.nukeStatus : "Press “Nuke Phone” to run the full sequence.\n\n1. Hard-kill animation scale to 0\n2. Force GPU rendering + disable hardware overlays\n3. Cap background processes at 2\n4. Turn off adaptive battery completely\n5. Kill location services + Wi-Fi/BT scanning\n6. Trim global + third-party cache\n7. Force-stop every third-party app\n8. Disable Samsung + Microsoft bloat"
                                                color: "#dde5a2"
                                                font.family: "Monospace"
                                                font.pixelSize: 12
                                                background: null
                                                wrapMode: TextEdit.WrapAnywhere
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // Selected App Information Box Output (Visible on Google, Third-Party, and Search tabs)
                // Description is fetched live from Gemini on left-click; safe-to-remove uses local heuristics
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: selectedAppInfo !== null ? 155 : 0
                    visible: selectedAppInfo !== null && (tabBar.currentIndex === 0 || tabBar.currentIndex === 1 || tabBar.currentIndex === 2)
                    color: Qt.rgba(0.22, 0.24, 0.21, 0.95)
                    radius: 8
                    border.color: "#b0ac63"
                    border.width: 1

                    Behavior on implicitHeight {
                        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 6

                        // Package name header
                        Text {
                            text: selectedAppInfo ? selectedAppInfo.pkg : ""
                            color: "#dde5a2"
                            font.pixelSize: 13
                            font.bold: true
                            font.family: "Monospace"
                            Layout.fillWidth: true
                            elide: Text.ElideMiddle
                        }

                        // Safe to remove status
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: "Safe to Remove:"
                                color: "#b0ac63"
                                font.pixelSize: 12
                                font.family: "Monospace"
                                font.bold: true
                            }

                            Text {
                                text: selectedAppInfo ? selectedAppInfo.safeToRemove : ""
                                color: selectedAppInfo ? (selectedAppInfo.safeToRemove === "Yes" ? "#88ff88" : (selectedAppInfo.safeToRemove === "No" ? "#ff7777" : "#ffff77")) : "#dde5a2"
                                font.pixelSize: 13
                                font.bold: true
                                font.family: "Monospace"
                            }
                        }

                        // Description (fetched live from Gemini) – scrollable so full text is readable
                        ScrollView {
                            id: descScroll
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: availableWidth
                            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                            ScrollBar.vertical.policy: ScrollBar.AsNeeded

                            Text {
                                width: descScroll.availableWidth
                                text: selectedAppInfo ? selectedAppInfo.description : ""
                                color: "#c8d0a0"
                                font.pixelSize: 12
                                font.family: "Monospace"
                                wrapMode: Text.WordWrap
                                // Full content is shown; user can scroll when text exceeds the panel height
                            }
                        }
                    }
                }

                Column {
                    Layout.fillWidth: true
                    spacing: 8

                    Button {
                        id: nukeBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 240
                        height: 44
                        visible: tabBar.currentIndex === 6
                        text: secureTabHelper.isNuking ? "Nuking…" : "Nuke Phone"
                        font.pixelSize: 14
                        font.family: "Monospace"
                        font.bold: true
                        enabled: !secureTabHelper.isNuking
                        scale: pressed ? 0.96 : 1.0
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.InOutQuad } }

                        background: Rectangle {
                            radius: 8
                            color: parent.enabled ? (parent.pressed ? Qt.darker("#5a2d2d", 1.1) : "#4a2424") : "#252627"
                            border.color: parent.enabled ? "#d9534f" : "#3a3a3a"
                            border.width: 1
                        }

                        contentItem: Text {
                            text: parent.text
                            font: parent.font
                            color: parent.enabled ? "#ffaaaa" : "#666666"
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        onClicked: secureTabHelper.startNukePhone()
                    }

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
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 90
                    color: Qt.rgba(0.18, 0.20, 0.17, 0.8)
                    radius: 8
                    border.color: "#555839"
                    border.width: 1
                    clip: true

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        // Storage Information Line
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 10

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

                        // Battery, Update Status, Released Year & Build Date Line
                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            Text {
                                text: "Battery: " + phoneBatteryLevel
                                color: "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                                font.bold: true
                            }

                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }

                            Text {
                                text: isUpdateAvailable ? "Update available" : "Up to date"
                                color: isUpdateAvailable ? "#ff5555" : "#dde5a2"
                                font.pixelSize: 12
                                font.family: "Monospace"
                                font.bold: isUpdateAvailable
                            }

                            Text {
                                text: "|"
                                color: "#555839"
                                font.pixelSize: 12
                                font.family: "Monospace"
                            }

                            Text {
                                text: "Released: " + phoneReleaseYear
                                color: "#b0ac63"
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
                border.color: (selectedAppInfo && selectedAppInfo.pkg === rawPkg) ? "#dde5a2" : (mouseArea.containsMouse ? "#b0ac63" : "#3a3c2c")
                border.width: (selectedAppInfo && selectedAppInfo.pkg === rawPkg) ? 2 : 1

                MouseArea {
                    id: mouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton
                    onClicked: mouse => {
                        let sysCheck = isSystemCritical(rawPkg);
                        selectedAppInfo = {
                            pkg: rawPkg,
                            description: "Querying Gemini for safety assessment and description…",
                            safeToRemove: "…",
                            category: sysCheck ? "System Package" : "User Package"
                        };
                        // Query Gemini for safety verdict + description
                        geminiDescProc.queryPkg(rawPkg);
                    }
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
            id: fetchThirdPartyAppsProc
            command: ["bash", "-c", "adb shell pm list packages -3 | sed 's/package://'"]

            stdout: StdioCollector {
                onStreamFinished: {
                    thirdPartyAppsModel.clear();
                    let lines = text.trim().split("\n");
                    let items = [];
                    for (let i = 0; i < lines.length; i++) {
                        let pkg = lines[i].trim();
                        if (pkg.length > 0 && !isSystemCritical(pkg)) {
                            items.push({
                                displayName: formatDisplayName(pkg),
                                       rawPkg: pkg,
                                       isInstalled: true,
                                       originalState: true
                            });
                        }
                    }
                    items.sort(function(a, b) {
                        return a.displayName.toLowerCase().localeCompare(b.displayName.toLowerCase());
                    });
                    for (let j = 0; j < items.length; j++) {
                        thirdPartyAppsModel.append(items[j]);
                    }
                    recalculateChanges();
                }
            }
        }

        Process {
            id: fetchGoogleAppsProc
            command: ["bash", "-c", "adb shell pm list packages | sed 's/package://' | grep -iE 'com.google|com.android.chrome'"]

            stdout: StdioCollector {
                onStreamFinished: {
                    googleAppsModel.clear();
                    let lines = text.trim().split("\n");
                    let items = [];
                    for (let i = 0; i < lines.length; i++) {
                        let pkg = lines[i].trim();
                        if (pkg.length > 0) {
                            items.push({
                                displayName: formatDisplayName(pkg),
                                       rawPkg: pkg,
                                       isInstalled: true,
                                       originalState: true
                            });
                        }
                    }
                    items.sort(function(a, b) {
                        return a.displayName.toLowerCase().localeCompare(b.displayName.toLowerCase());
                    });
                    for (let j = 0; j < items.length; j++) {
                        googleAppsModel.append(items[j]);
                    }
                    recalculateChanges();
                }
            }
        }

        Process {
            id: checkDepsProc
            command: ["which", "clamscan"]
            stdout: StdioCollector {
                onStreamFinished: {
                    depsInstalled = text.trim().length > 0;
                }
            }
        }

        Process {
            id: fetchBatteryProc
            command: ["adb", "shell", "cmd", "battery", "get", "level"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let level = text.trim().replace(/\r/g, "");
                    if (level.length > 0 && !isNaN(level)) {
                        phoneBatteryLevel = level + "%";
                    } else {
                        phoneBatteryLevel = "-";
                    }
                }
            }
        }

        Process {
            id: fetchDeviceInfoProc
            command: [
                "bash", "-c",
                "echo MANUFACTURER=$(adb shell getprop ro.product.manufacturer 2>/dev/null | tr -d '\\r'); " +
                "echo MODEL=$(adb shell getprop ro.product.model 2>/dev/null | tr -d '\\r'); " +
                "echo ANDROID=$(adb shell getprop ro.build.version.release 2>/dev/null | tr -d '\\r'); " +
                "echo SERIAL=$(adb shell getprop ro.serialno 2>/dev/null | tr -d '\\r'); " +
                "echo BUILDDATE=$(adb shell getprop ro.build.date 2>/dev/null | tr -d '\\r'); " +
                "echo FIRSTAPI=$(adb shell getprop ro.product.first_api_level 2>/dev/null | tr -d '\\r')"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    let lines = text.trim().split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (line.startsWith("MANUFACTURER=")) {
                            let val = line.substring(13).trim();
                            phoneManufacturer = val.length > 0 ? val : "Unknown";
                        } else if (line.startsWith("MODEL=")) {
                            let val = line.substring(6).trim();
                            phoneModel = val.length > 0 ? val : "Unknown";
                        } else if (line.startsWith("ANDROID=")) {
                            let val = line.substring(8).trim();
                            phoneAndroid = val.length > 0 ? val : "Unknown";
                        } else if (line.startsWith("SERIAL=")) {
                            let val = line.substring(7).trim();
                            phoneSerial = val.length > 0 ? val : "Unknown";
                        } else if (line.startsWith("BUILDDATE=")) {
                            let val = line.substring(10).trim();
                            phoneBuildDate = val.length > 0 ? val : "-";
                        } else if (line.startsWith("FIRSTAPI=")) {
                            let api = parseInt(line.substring(9).trim());
                            // Map first API level to approximate original release year
                            let yearMap = {
                                21: 2014, 22: 2015, 23: 2015, 24: 2016, 25: 2016,
                                26: 2017, 27: 2018, 28: 2018, 29: 2019, 30: 2020,
                                31: 2021, 32: 2022, 33: 2022, 34: 2023, 35: 2024,
                                36: 2025
                            };
                            phoneReleaseYear = yearMap[api] ? String(yearMap[api]) : (isNaN(api) ? "-" : "API " + api);
                        }
                    }
                }
            }
        }

        Process {
            id: fetchStorageProc
            command: [
                "bash", "-c",
                "adb shell df -h /data 2>/dev/null | tail -1 | tr -d '\\r'"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    // Typical df -h output: Filesystem Size Used Avail Use% Mounted
                    // e.g. /dev/block/...  110G  45G  65G  41% /data
                    let line = text.trim();
                    if (line.length === 0) {
                        storageTotal = "-";
                        storageUsed = "-";
                        storageAvail = "-";
                        return;
                    }
                    let parts = line.split(/\s+/);
                    // Find the size/used/avail fields (usually indices 1,2,3)
                    if (parts.length >= 4) {
                        // Skip filesystem name; take Size, Used, Available
                        storageTotal = parts[1] || "-";
                        storageUsed  = parts[2] || "-";
                        storageAvail = parts[3] || "-";
                    } else {
                        storageTotal = "-";
                        storageUsed = "-";
                        storageAvail = "-";
                    }
                }
            }
        }

        Process {
            id: checkUpdateProc
            command: [
                "bash", "-c",
                "adb shell 'dumpsys update_engine 2>/dev/null | grep -i status || dumpsys ota 2>/dev/null | grep -i status || getprop sys.ota.status 2>/dev/null'"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    let output = text.trim().toLowerCase();
                    isUpdateAvailable = output.includes("update_available") ||
                    output.includes("downloading") ||
                    output.includes("pending") ||
                    output.includes("ready_to_reboot");
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
                    let lines = text.trim().split("\n");
                    let q = searchPhoneProc.queryTerm.trim().toLowerCase();
                    if (q.length === 0) return;

                    // Special smart keywords
                    let mode = "normal"; // normal | services | google | thirdparty
                    if (q === "services" || q === "service" || q === "system services") {
                        mode = "services";
                    } else if (q === "google apps" || q === "google" || q === "google app") {
                        mode = "google";
                    } else if (q === "third party" || q === "third-party" || q === "thirdparty" ||
                        q === "user" || q === "user apps" || q === "third party apps") {
                        mode = "thirdparty";
                        }

                        for (let i = 0; i < lines.length; i++) {
                            let pkg = lines[i].trim();
                            if (pkg.length === 0) continue;

                            let disp = formatDisplayName(pkg);
                            let include = false;

                            if (mode === "services") {
                                // Heuristics for system / service-like packages
                                let isServiceLike = isSystemCritical(pkg) ||
                                    pkg.includes(".service") ||
                                    pkg.includes("provider") ||
                                    pkg.includes("overlay") ||
                                    pkg.includes("framework") ||
                                    pkg.includes("systemui") ||
                                    pkg.startsWith("android.") ||
                                    pkg.startsWith("com.android.") ||
                                    pkg.startsWith("com.samsung.") ||
                                    pkg.startsWith("com.sec.");
                                include = isServiceLike;
                            } else if (mode === "google") {
                                include = pkg.toLowerCase().includes("com.google") ||
                                pkg.toLowerCase() === "com.android.chrome" ||
                                pkg.toLowerCase().includes("com.android.chrome");
                            } else if (mode === "thirdparty") {
                                // Third-party / user apps: not system-critical
                                include = !isSystemCritical(pkg) &&
                                !pkg.startsWith("com.google.") &&
                                !pkg.startsWith("com.android.") &&
                                !pkg.startsWith("android.") &&
                                !pkg.startsWith("com.samsung.") &&
                                !pkg.startsWith("com.sec.");
                            } else {
                                // Normal substring search
                                include = pkg.toLowerCase().includes(q) || disp.toLowerCase().includes(q);
                            }

                            if (include) {
                                searchResultsModel.append({
                                    displayName: disp,
                                    rawPkg: pkg,
                                    isInstalled: true,
                                    originalState: true
                                });
                            }
                        }
                }
            }
        }

        Process {
            id: actionProc
            property string currentPkg: ""
            property bool isFallbackMode: false
            command: []

            onExited: (code, status) => {
                if (code === 0) {
                    statusText.text += " Successfully processed " + currentPkg + "\n";
                    processNextAction();
                } else {
                    if (!isFallbackMode) {
                        isFallbackMode = true;
                        statusText.text += " Package manager command failed. Attempting ADB fallback for " + currentPkg + "...\n";
                        command = ["adb", "shell", "pm", "disable-user", "--user", "0", currentPkg];
                        running = true;
                    } else {
                        statusText.text += " Failed to process " + currentPkg + "\n";
                        processNextAction();
                    }
                }
            }
        }

        Process {
            id: rebootRecoveryProc
            command: ["adb", "reboot", "recovery"]
        }

        Process {
            id: rebootBootloaderProc
            command: ["adb", "reboot", "bootloader"]
        }

        Process {
            id: killScrcpyProc
            command: ["pkill", "scrcpy"]
        }

        Process {
            id: startScrcpyProc
            command: ["scrcpy"]
        }

        Process {
            id: installFDroidProc
            command: ["bash", "-c", "curl -s -L 'https://f-droid.org/F-Droid.apk' -o /tmp/FDroid.apk && adb install /tmp/FDroid.apk && rm /tmp/FDroid.apk"]
            onExited: code => {
                if (code === 0) {
                    isFDroidInstalled = true;
                }
            }
        }

        Process {
            id: openFDroidProc
            command: ["adb", "shell", "monkey", "-p", "org.fdroid.fdroid", "-c", "android.intent.category.LAUNCHER", "1"]
        }

        Process {
            id: playStoreConnectCheckProc
            command: ["adb", "shell", "pm", "list", "packages", "com.android.vending"]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0 && pendingPlayStorePkg !== "") {
                        let launchProc = Qt.createQmlObject('import Quickshell.Io 1.0; Process {}', window);
                        launchProc.command = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "market://details?id=" + pendingPlayStorePkg];
                        launchProc.running = true;
                    }
                    pendingPlayStorePkg = "";
                }
            }
        }

        // ------------------------------------------------------------------
        // Load Gemini API key from a local file (never hard-coded).
        // Search order:
        //   1. ~/.config/debloat-phone/gemini.key
        //   2. gemini.key next to this QML file
        // ------------------------------------------------------------------
        Process {
            id: loadGeminiKeyProc
            // Resolve local gemini.key relative to this QML file so it works
            // regardless of the current working directory.
            property string localKeyPath: Qt.resolvedUrl("gemini.key").toString().replace("file://", "")
            command: [
                "bash", "-c",
                "KEYFILE=\"$HOME/.config/debloat-phone/gemini.key\"; " +
                "LOCALKEY=\"" + localKeyPath + "\"; " +
                "if [ -f \"$KEYFILE\" ]; then cat \"$KEYFILE\"; " +
                "elif [ -f \"$LOCALKEY\" ]; then cat \"$LOCALKEY\"; " +
                "else echo \"\"; fi"
            ]
            running: false

            stdout: StdioCollector {
                onStreamFinished: {
                    let key = text.trim().replace(/\r/g, "");
                    // Strip possible "Bearer " or quotes if user added them by mistake
                    if (key.toLowerCase().startsWith("bearer ")) {
                        key = key.substring(7).trim();
                    }
                    if ((key.startsWith("\"") && key.endsWith("\"")) ||
                        (key.startsWith("'") && key.endsWith("'"))) {
                        key = key.substring(1, key.length - 1);
                    }
                    geminiApiKey = key;
                    geminiKeyLoaded = true;
                    if (key.length > 0) {
                        console.log("[Gemini] API key loaded successfully (length " + key.length + ")");
                    } else {
                        console.log("[Gemini] No API key found. Place your key in ~/.config/debloat-phone/gemini.key or gemini.key next to the QML file.");
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    geminiKeyLoaded = true;
                    if (text.trim().length > 0) {
                        console.log("[Gemini] Key load error:", text.trim());
                    }
                }
            }
        }

        // ------------------------------------------------------------------
        // Gemini model discovery + description lookup
        // On first use we query the ListModels endpoint, prefer free Flash
        // models, then cache the choice for subsequent package lookups.
        // ------------------------------------------------------------------
        Process {
            id: geminiListModelsProc
            command: []
            running: false

            function startDiscovery() {
                command = [
                    "bash", "-c",
                    "curl -s -X GET 'https://generativelanguage.googleapis.com/v1beta/models' " +
                    "-H 'x-goog-api-key: " + geminiApiKey + "'"
                ];
                running = true;
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    let chosen = "";
                    try {
                        let resp = JSON.parse(text.trim());
                        let models = resp.models || [];
                        // Collect candidates that support generateContent
                        let candidates = [];
                        for (let i = 0; i < models.length; i++) {
                            let m = models[i];
                            let name = (m.name || "").replace(/^models\//, "");
                            let methods = m.supportedGenerationMethods || [];
                            if (methods.indexOf("generateContent") === -1) continue;
                            // Prefer free-tier friendly flash models; de-prioritise pro / thinking / experimental
                            let score = 0;
                            let lower = name.toLowerCase();
                            if (lower.includes("flash")) score += 50;
                            if (lower.includes("lite")) score += 10;
                            if (lower.includes("2.5") || lower.includes("2.0") || lower.includes("1.5")) score += 20;
                            if (lower.includes("3.")) score += 25;          // newer generations
                            if (lower.includes("pro")) score -= 30;
                            if (lower.includes("ultra")) score -= 40;
                            if (lower.includes("thinking") || lower.includes("exp")) score -= 15;
                            candidates.push({ name: name, score: score });
                        }
                        // Sort highest score first
                        candidates.sort(function(a, b) { return b.score - a.score; });
                        if (candidates.length > 0) {
                            chosen = candidates[0].name;
                            // Keep the full ordered list for automatic fallback on high-demand errors
                            let names = [];
                            for (let c = 0; c < candidates.length; c++) {
                                names.push(candidates[c].name);
                            }
                            geminiModelCandidates = names;
                            console.log("[Gemini] Selected primary model:", chosen,
                                        "(score", candidates[0].score + "). Fallbacks:", names.slice(1, 6).join(", "));
                        }
                    } catch (e) {
                        console.log("[Gemini] Failed to parse ListModels response:", e);
                    }

                    // Fallbacks if discovery failed or returned nothing useful
                    if (chosen === "") {
                        chosen = "gemini-2.5-flash";
                        geminiModelCandidates = [
                            "gemini-2.5-flash",
                            "gemini-2.0-flash",
                            "gemini-1.5-flash",
                            "gemini-2.5-flash-lite",
                            "gemini-1.5-flash-8b"
                        ];
                        console.log("[Gemini] Using fallback model list, primary:", chosen);
                    }

                    geminiModel = chosen;
                    geminiModelIndex = 0;
                    geminiModelsQueried = true;

                    // If a package was waiting, continue with the description query
                    if (pendingGeminiPkg !== "") {
                        let pkg = pendingGeminiPkg;
                        pendingGeminiPkg = "";
                        geminiDescProc.doGenerate(pkg);
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length > 0) {
                        console.log("[Gemini] ListModels stderr:", text.trim().substring(0, 200));
                    }
                    // Still mark as queried and use a safe fallback list
                    if (!geminiModelsQueried) {
                        geminiModel = "gemini-2.5-flash";
                        geminiModelCandidates = [
                            "gemini-2.5-flash",
                            "gemini-2.0-flash",
                            "gemini-1.5-flash",
                            "gemini-2.5-flash-lite",
                            "gemini-1.5-flash-8b"
                        ];
                        geminiModelIndex = 0;
                        geminiModelsQueried = true;
                        if (pendingGeminiPkg !== "") {
                            let pkg = pendingGeminiPkg;
                            pendingGeminiPkg = "";
                            geminiDescProc.doGenerate(pkg);
                        }
                    }
                }
            }
        }

        Process {
            id: geminiDescProc
            property string currentPkg: ""
            command: []

            // Public entry point – discovers model on first call
            function queryPkg(pkg) {
                currentPkg = pkg;

                // Wait until the key has been loaded from disk
                if (!geminiKeyLoaded) {
                    // Key loader is still running – re-try shortly
                    Qt.callLater(function() { geminiDescProc.queryPkg(pkg); });
                    return;
                }

                if (geminiApiKey.length === 0) {
                    if (selectedAppInfo && selectedAppInfo.pkg === pkg) {
                        selectedAppInfo = {
                            pkg: pkg,
                            description: "No Gemini API key found.\n\nCreate the file:\n  ~/.config/debloat-phone/gemini.key\n(or place gemini.key next to this QML file)\nand put your free API key inside it (one line only).\n\nGet a key at: https://aistudio.google.com/apikey",
                            safeToRemove: "—",
                            category: selectedAppInfo.category
                        };
                    }
                    return;
                }

                if (!geminiModelsQueried) {
                    // First time: discover available free models, then continue
                    pendingGeminiPkg = pkg;
                    if (selectedAppInfo && selectedAppInfo.pkg === pkg) {
                        selectedAppInfo = {
                            pkg: pkg,
                            description: "Discovering available Gemini models…",
                            safeToRemove: "…",
                            category: selectedAppInfo.category
                        };
                    }
                    geminiListModelsProc.startDiscovery();
                    return;
                }
                doGenerate(pkg);
            }

            // Actual generateContent call once a model is known
            function doGenerate(pkg) {
                currentPkg = pkg;

                // Pick the model for this attempt
                let model = geminiModel || "gemini-2.5-flash";
                if (geminiModelCandidates.length > 0) {
                    if (geminiModelIndex < 0 || geminiModelIndex >= geminiModelCandidates.length) {
                        geminiModelIndex = 0;
                    }
                    model = geminiModelCandidates[geminiModelIndex];
                }

                // Ask for a clear safety verdict first, then a longer description
                let prompt =
                    "For the Android package \"" + pkg + "\":\n" +
                    "1. First line exactly in this format: Safe to remove: Yes   OR   Safe to remove: No   OR   Safe to remove: Caution\n" +
                    "2. Second line: a short reason (max 15 words).\n" +
                    "3. Then a blank line followed by a concise description of what the package does (max 80 words).\n" +
                    "Focus on a regular user's perspective. Do not mention this prompt.";
                let bodyObj = {
                    contents: [{
                        parts: [{ text: prompt }]
                    }]
                };
                let jsonBody = JSON.stringify(bodyObj);
                let escapedBody = jsonBody.replace(/'/g, "'\\''");
                command = [
                    "bash", "-c",
                    "curl -s -X POST 'https://generativelanguage.googleapis.com/v1beta/models/" + model + ":generateContent' " +
                    "-H 'x-goog-api-key: " + geminiApiKey + "' " +
                    "-H 'Content-Type: application/json' " +
                    "-d '" + escapedBody + "'"
                ];
                running = true;
            }

            // Returns true if the error message indicates the model is overloaded / high demand
            function isHighDemandError(msg) {
                if (!msg) return false;
                let m = msg.toLowerCase();
                return m.includes("high demand") ||
                       m.includes("high volume") ||
                       m.includes("currently experiencing") ||
                       m.includes("resource exhausted") ||
                       m.includes("rate limit") ||
                       m.includes("quota") ||
                       m.includes("try again later") ||
                       m.includes("overloaded") ||
                       m.includes("unavailable") ||
                       m.includes("429") ||
                       m.includes("503");
            }

            // Try the next model in the candidate list. Returns true if a retry was started.
            function tryNextModel(pkg) {
                if (geminiModelCandidates.length === 0) return false;
                let next = geminiModelIndex + 1;
                if (next >= geminiModelCandidates.length) {
                    console.log("[Gemini] All candidate models exhausted.");
                    return false;
                }
                geminiModelIndex = next;
                let nextModel = geminiModelCandidates[next];
                console.log("[Gemini] Switching to fallback model:", nextModel);
                if (selectedAppInfo && selectedAppInfo.pkg === pkg) {
                    selectedAppInfo = {
                        pkg: pkg,
                        description: "Model busy – trying " + nextModel + "…",
                        safeToRemove: "…",
                        category: selectedAppInfo.category
                    };
                }
                doGenerate(pkg);
                return true;
            }

            stdout: StdioCollector {
                onStreamFinished: {
                    let safeStatus = "Unknown";
                    let desc = "No description returned from Gemini.";
                    let shouldRetry = false;
                    let errorMsg = "";

                    try {
                        let resp = JSON.parse(text.trim());
                        if (resp.candidates && resp.candidates.length > 0 &&
                            resp.candidates[0].content && resp.candidates[0].content.parts &&
                            resp.candidates[0].content.parts.length > 0) {
                            let raw = resp.candidates[0].content.parts[0].text.trim();

                            // Parse structured response
                            // Expected:
                            // Safe to remove: Yes/No/Caution
                            // short reason
                            //
                            // longer description...
                            let lines = raw.split(/\r?\n/);
                            let firstLine = (lines[0] || "").trim();
                            let lowerFirst = firstLine.toLowerCase();

                            if (lowerFirst.startsWith("safe to remove:")) {
                                let verdict = firstLine.substring("safe to remove:".length).trim();
                                // Normalise to Yes / No / Caution
                                let vLower = verdict.toLowerCase();
                                if (vLower.startsWith("yes")) safeStatus = "Yes";
                                else if (vLower.startsWith("no")) safeStatus = "No";
                                else if (vLower.startsWith("caution") || vLower.startsWith("maybe")) safeStatus = "Caution";
                                else safeStatus = verdict;   // keep original if unexpected

                                // Collect remaining text as description (skip blank lines after the verdict)
                                let descLines = [];
                                let started = false;
                                for (let i = 1; i < lines.length; i++) {
                                    let ln = lines[i];
                                    if (!started && ln.trim() === "") continue;
                                    started = true;
                                    descLines.push(ln);
                                }
                                if (descLines.length > 0) {
                                    desc = descLines.join("\n").trim();
                                } else {
                                    desc = raw;   // fallback
                                }
                            } else {
                                // Model did not follow the format – use whole text as description
                                // and try a simple heuristic for safety
                                desc = raw;
                                if (raw.toLowerCase().includes("not safe") || raw.toLowerCase().includes("do not remove") ||
                                    raw.toLowerCase().includes("critical") || raw.toLowerCase().includes("essential")) {
                                    safeStatus = "No";
                                } else if (raw.toLowerCase().includes("safe to remove") || raw.toLowerCase().includes("can be removed")) {
                                    safeStatus = "Yes";
                                } else {
                                    safeStatus = "Caution";
                                }
                            }

                            // Success – remember this model as the preferred one for next time
                            if (geminiModelCandidates.length > 0 && geminiModelIndex < geminiModelCandidates.length) {
                                geminiModel = geminiModelCandidates[geminiModelIndex];
                            }
                        } else if (resp.error) {
                            errorMsg = resp.error.message || JSON.stringify(resp.error);
                            desc = "Gemini error: " + errorMsg;
                            safeStatus = "Unknown";
                            if (isHighDemandError(errorMsg)) {
                                shouldRetry = true;
                            }
                        }
                    } catch (e) {
                        // Sometimes the API returns a plain-text error instead of JSON
                        let rawText = text.trim();
                        if (isHighDemandError(rawText)) {
                            errorMsg = rawText;
                            shouldRetry = true;
                            desc = "Gemini error: " + rawText.substring(0, 180);
                        } else {
                            desc = "Failed to parse Gemini response: " + e + "\nRaw: " + rawText.substring(0, 120);
                        }
                        safeStatus = "Unknown";
                    }

                    // Automatic fallback on high-demand / overloaded models
                    if (shouldRetry && selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        if (tryNextModel(geminiDescProc.currentPkg)) {
                            return;   // retry started – do not update UI with the error yet
                        }
                    }

                    // Only update if the user has not clicked a different package in the meantime
                    if (selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        selectedAppInfo = {
                            pkg: geminiDescProc.currentPkg,
                            description: desc,
                            safeToRemove: safeStatus,
                            category: selectedAppInfo.category
                        };
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length === 0) return;
                    let err = text.trim();
                    // Attempt automatic fallback on high-demand style errors reported via stderr
                    if (isHighDemandError(err) && selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        if (tryNextModel(geminiDescProc.currentPkg)) {
                            return;
                        }
                    }
                    if (selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        selectedAppInfo = {
                            pkg: geminiDescProc.currentPkg,
                            description: "Gemini query error: " + err.substring(0, 150),
                            safeToRemove: selectedAppInfo.safeToRemove,
                            category: selectedAppInfo.category
                        };
                    }
                }
            }
        }

        Timer {
            id: scrcpyReconnectTimer
            interval: 2000
            repeat: false
            onTriggered: {
                if (isPhoneVisible) {
                    startScrcpyProc.running = true;
                }
            }
        }
    }
}
