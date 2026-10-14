import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCore
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtMultimedia

ShellRoot {
    property var appsToUninstall: ([])
    property var appsToEnable: ([])
    property var launchableApps: ([])
    property bool isPhoneVisible: false
    property bool isFDroidInstalled: false
    property bool searchAttempted: false
    property string pendingPlayStorePkg: ""
    property int currentColumn: 0          // 0=Google … 7=Nuke

    onCurrentColumnChanged: {
        selectedAppInfo = null
        if (currentColumn === 2) {
            searchField.forceActiveFocus()
        } else if (currentColumn === 4) {
            sharedTabHelper.onTabSelected()
        } else if (currentColumn === 5) {
            monitoringTabHelper.onTabSelected()
        } else if (currentColumn === 6) {
            secureTabHelper.fetchBatteryOptimization()
        } else if (currentColumn === 7) {
            fetchThumbnailsProc.running = true
        } else if (currentColumn === 9) {
            camMicHelper.fetchCamMicApps()
        } else if (currentColumn === 10) {
            appConnHelper.startMonitoring()
        } else {
            monitoringTabHelper.onTabDeselected()
            if (typeof appConnHelper !== "undefined" && appConnHelper)
                appConnHelper.stopMonitoring()
        }
        // Stop connection monitor when leaving that tab
        if (currentColumn !== 10 && typeof appConnHelper !== "undefined" && appConnHelper)
            appConnHelper.stopMonitoring()
        // Stop local video when leaving Video tab
        if (currentColumn !== 12 && typeof videoTabHelper !== "undefined" && videoTabHelper)
            videoTabHelper.stopVideo()
    }

    property string phoneManufacturer: "Unknown"
    property string phoneModel: "Unknown"
    property string phoneAndroid: "Unknown"
    property string phoneSerial: "Unknown"
    property string phoneReleaseYear: "-"
    property string phoneBuildDate: "-"
    // Brand family for adaptive paths / settings: samsung | google | xiaomi | oneplus | generic
    property string phoneBrandFamily: "generic"
    property int phoneSdkInt: 0
    // Thumbnail cache stats (Nuke tab)
    property int thumbnailCount: 0
    property string thumbnailSizeLabel: "-"

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

    // Narrower filter for the Battery tab: hide only packages that must not be
    // deep-slept (phone, contacts, system UI, settings, core providers, GMS).
    // Preinstalled apps such as Camera, Calendar, Radio, Gallery remain listed.
    function isBatteryListExcluded(pkg) {
        if (!pkg) return true;
        let n = pkg.toLowerCase();

        // Explicit critical packages
        let criticalExact = [
            "android",
            "com.android.systemui",
            "com.android.settings",
            "com.android.phone",
            "com.android.providers.telephony",
            "com.android.providers.contacts",
            "com.android.providers.settings",
            "com.android.providers.media",
            "com.android.packageinstaller",
            "com.android.keychain",
            "com.android.shell",
            "com.android.permissioncontroller",
            "com.android.bluetooth",
            "com.android.nfc",
            "com.android.se",
            "com.google.android.gms",
            "com.google.android.gsf",
            "com.samsung.android.incallui",
            "com.samsung.android.dialer",
            "com.samsung.android.app.contacts",
            "com.samsung.android.providers.contacts",
            "com.sec.android.app.launcher",
            "com.samsung.android.launcher",
            "com.miui.home"
        ];
        if (criticalExact.indexOf(pkg) !== -1 || criticalExact.indexOf(n) !== -1)
            return true;

        // Pattern-based critical / framework noise
        if (n.includes("systemui") ||
            n.includes("incallui") ||
            n.includes(".dialer") ||
            n.includes("com.android.phone") ||
            n.includes("providers.telephony") ||
            n.includes("providers.contacts") ||
            n.includes("providers.settings") ||
            n.includes("permissioncontroller") ||
            n.includes("packageinstaller") ||
            n.includes(".overlay.") ||
            n.includes(".framework.") ||
            n.includes("vendor.") ||
            n.includes("qualcomm") ||
            n.includes(".qti.") ||
            n.includes("networkstack") ||
            n.includes("cellbroadcast") ||
            n.includes("keychain") ||
            n.includes("com.android.shell") ||
            n.includes("com.google.android.gms") ||
            n.includes("com.google.android.gsf") ||
            n.includes("wssyncmldm") ||
            n.includes("com.android.vending")) {
            return true;
        }
        return false;
    }

    
    function isSystemNetworkService(pkg) {
        let n = (pkg || "").toLowerCase();
        if (n.indexOf("uid:") === 0) return true;
        if (n === "system" || n === "root" || n === "shell") return true;
        if (n.indexOf("com.google.") === 0) return true;
        if (n.indexOf("com.android.") === 0) return true;
        if (n.indexOf("android.") === 0) return true;
        if (n.indexOf("com.samsung.") === 0) return true;
        if (n.indexOf("com.sec.") === 0) return true;
        if (n.indexOf("com.qualcomm.") === 0) return true;
        if (n.indexOf("com.qti.") === 0) return true;
        if (n.indexOf("com.mediatek.") === 0) return true;
        if (n.indexOf("com.wssyncmldm") === 0) return true;
        return false;
    }


    function detectBrandFamily(manufacturer, model) {
        let m = (manufacturer || "").toLowerCase();
        let mod = (model || "").toLowerCase();
        if (m.indexOf("samsung") >= 0 || m === "sec") return "samsung";
        if (m.indexOf("google") >= 0 || mod.indexOf("pixel") >= 0) return "google";
        if (m.indexOf("xiaomi") >= 0 || m.indexOf("redmi") >= 0 || m.indexOf("poco") >= 0 ||
            mod.indexOf("redmi") >= 0 || mod.indexOf("poco") >= 0) return "xiaomi";
        if (m.indexOf("oneplus") >= 0 || m.indexOf("oppo") >= 0 || mod.indexOf("oneplus") >= 0)
            return "oneplus";
        return "generic";
    }

    // Brand-priority thumbnail dirs; always end with generic .thumbnails search
    function thumbnailDirHints() {
        let common = [
            "/sdcard/DCIM/.thumbnails",
            "/sdcard/Pictures/.thumbnails",
            "/sdcard/Android/data/com.google.android.apps.photos/cache"
        ];
        if (phoneBrandFamily === "samsung") {
            return [
                "/sdcard/DCIM/.thumbnails",
                "/sdcard/Android/data/com.sec.android.gallery3d/cache",
                "/sdcard/Android/data/com.samsung.android.gallery3d/cache",
                "/sdcard/Android/data/com.sec.android.gallery3d/files",
                "/sdcard/Pictures/.thumbnails"
            ].concat(common);
        }
        if (phoneBrandFamily === "xiaomi") {
            return [
                "/sdcard/DCIM/.thumbnails",
                "/sdcard/Android/data/com.miui.gallery/cache",
                "/sdcard/Android/data/com.miui.gallery/files",
                "/sdcard/Pictures/.thumbnails"
            ].concat(common);
        }
        if (phoneBrandFamily === "oneplus") {
            return [
                "/sdcard/DCIM/.thumbnails",
                "/sdcard/Android/data/com.oneplus.gallery/cache",
                "/sdcard/Android/data/com.oplus.gallery/cache",
                "/sdcard/Pictures/.thumbnails"
            ].concat(common);
        }
        if (phoneBrandFamily === "google") {
            return [
                "/sdcard/DCIM/.thumbnails",
                "/sdcard/Android/data/com.google.android.apps.photos/cache",
                "/sdcard/Pictures/.thumbnails"
            ].concat(common);
        }
        return common;
    }

    function formatBytes(n) {
        n = Number(n) || 0;
        if (n < 1024) return n + " B";
        if (n < 1024 * 1024) return (n / 1024).toFixed(1) + " KB";
        if (n < 1024 * 1024 * 1024) return (n / (1024 * 1024)).toFixed(1) + " MB";
        return (n / (1024 * 1024 * 1024)).toFixed(2) + " GB";
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

        // Switch to Google column so the user can see progress
        currentColumn = 0;
        columnsFlick.contentX = 0; currentColumn = 0;
        statusScrollView.visible = true;
        statusText.text = "Starting package state updates...\n";
        processNextAction();
    }

    function processNextAction() {
        if (pendingActionsQueue.length === 0) {
            statusText.text += "\nFinished applying changes. Refreshing package list...\n";
            // Hide status panel and show the app lists again
            statusScrollView.visible = false;
            appsToUninstall = [];
            appsToEnable = [];
            // Re-fetch Google + Third-Party package lists from the device
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
        fetchThumbnailsProc.running = true;
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

                // Page indicator – two rows (no horizontal scroll)
                Rectangle {
                    Layout.fillWidth: true
                    height: 72
                    color: Qt.rgba(0.18, 0.20, 0.17, 0.9)
                    radius: 8
                    border.color: "#555839"
                    border.width: 1

                    Column {
                        id: pageIndicator
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 4

                        property var row1: ["Google", "Third-Party", "Search", "Reboot", "Shared", "Monitor"]
                        property var row2: ["Battery", "Nuke", "Secure", "Cam/Mic", "Connections", "Install", "Video", "Personal"]

                        function tabIndex(row, i) {
                            return row === 0 ? i : (6 + i)
                        }

                        Row {
                            width: parent.width
                            height: (parent.height - parent.spacing) / 2
                            spacing: 4
                            Repeater {
                                model: pageIndicator.row1
                                delegate: Rectangle {
                                    width: (pageIndicator.width - 5 * 4) / 6
                                    height: parent.height
                                    radius: 6
                                    color: pageIndicator.tabIndex(0, index) === currentColumn ? "#363c30" : "transparent"
                                    border.color: pageIndicator.tabIndex(0, index) === currentColumn ? "#555839" : "transparent"
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: pageIndicator.tabIndex(0, index) === currentColumn ? "#dde5a2" : "#888888"
                                        font.pixelSize: 11
                                        font.family: "Monospace"
                                        font.bold: pageIndicator.tabIndex(0, index) === currentColumn
                                        elide: Text.ElideRight
                                        width: parent.width - 4
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var idx = pageIndicator.tabIndex(0, index)
                                            currentColumn = idx
                                            columnsFlick.contentX = idx * columnsFlick.width
                                        }
                                    }
                                }
                            }
                        }

                        Row {
                            width: parent.width
                            height: (parent.height - parent.spacing) / 2
                            spacing: 4
                            Repeater {
                                model: pageIndicator.row2
                                delegate: Rectangle {
                                    width: (pageIndicator.width - 7 * 4) / 8
                                    height: parent.height
                                    radius: 6
                                    color: pageIndicator.tabIndex(1, index) === currentColumn ? "#363c30" : "transparent"
                                    border.color: pageIndicator.tabIndex(1, index) === currentColumn ? "#555839" : "transparent"
                                    border.width: 1
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: pageIndicator.tabIndex(1, index) === currentColumn ? "#dde5a2" : "#888888"
                                        font.pixelSize: 11
                                        font.family: "Monospace"
                                        font.bold: pageIndicator.tabIndex(1, index) === currentColumn
                                        elide: Text.ElideRight
                                        width: parent.width - 4
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var idx = pageIndicator.tabIndex(1, index)
                                            currentColumn = idx
                                            columnsFlick.contentX = idx * columnsFlick.width
                                        }
                                    }
                                }
                            }
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

                    Flickable {
                        id: columnsFlick
                        anchors.fill: parent
                        anchors.margins: 0
                        contentWidth: columnsRow.width
                        contentHeight: height
                        clip: true
                        interactive: true
                        boundsBehavior: Flickable.StopAtBounds
                        flickableDirection: Flickable.HorizontalFlick

                        // Snap to nearest column after a flick
                        onMovementEnded: {
                            var page = Math.round(contentX / width)
                            page = Math.max(0, Math.min(page, 13))
                            contentX = page * width
                            currentColumn = page
                            selectedAppInfo = null
                            if (page === 2) searchField.forceActiveFocus()
                            else if (page === 4) sharedTabHelper.onTabSelected()
                            else if (page === 5) monitoringTabHelper.onTabSelected()
                            else if (page === 6) secureTabHelper.fetchBatteryOptimization()
                            else if (page === 7) { fetchThumbnailsProc.running = true }
                            else if (page === 9) camMicHelper.fetchCamMicApps()
                            else if (page === 10) appConnHelper.startMonitoring()
                            else monitoringTabHelper.onTabDeselected()
                        }

                        Row {
                            id: columnsRow
                            height: columnsFlick.height
                            spacing: 0

                        Item {
                            width: columnsFlick.width
                            height: columnsFlick.height
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
                            width: columnsFlick.width
                            height: columnsFlick.height
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
                            width: columnsFlick.width
                            height: columnsFlick.height
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
                            width: columnsFlick.width
                            height: columnsFlick.height
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
                            width: columnsFlick.width
                            height: columnsFlick.height
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
                                        console.log("[SHARED] adb push " + filePath + " -> " + remoteSharedFolder + "/");
                                        statusNoticeText.text = "Uploading: " + filePath.split("/").pop() + "...";
                                        // argv form handles spaces; no shell quoting needed
                                        adbPushProc.command = ["adb", "push", filePath, remoteSharedFolder + "/"];
                                        adbPushProc.running = true;
                                    } else {
                                        statusNoticeText.text = "Upload finished";
                                        statusNoticeTimer.restart();
                                        sharedTabHelper.readDirectoryContents();
                                    }
                                }

                                onExited: function(exitCode) {
                                    console.log("[SHARED] push exit=" + exitCode);
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
                                        if (!drop.hasUrls) return;
                                        let filesToPush = [];
                                        for (let i = 0; i < drop.urls.length; i++) {
                                            let u = drop.urls[i];
                                            let path = "";
                                            // Prefer toLocalFile when available (correct on Linux)
                                            try {
                                                if (u && u.toLocalFile)
                                                    path = u.toLocalFile();
                                            } catch (e) {}
                                            if (!path || path.length === 0) {
                                                path = (u && u.toString) ? u.toString() : ("" + u);
                                                if (path.indexOf("file://") === 0)
                                                    path = path.substring(7);
                                                // file:///home/... → strip possible extra slash handled already
                                                if (path.indexOf("localhost/") === 0)
                                                    path = path.substring(9);
                                                path = decodeURIComponent(path);
                                            }
                                            if (path.length > 0)
                                                filesToPush.push(path);
                                        }
                                        console.log("[SHARED] drop files: " + JSON.stringify(filesToPush));
                                        if (filesToPush.length > 0) {
                                            statusNoticeText.text = "Uploading " + filesToPush.length + " file(s) to phone...";
                                            adbPushProc.fileQueue = filesToPush.slice();
                                            if (adbPushProc.running)
                                                adbPushProc.running = false;
                                            adbPushProc.pushNext();
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
                                                            let remotePath = remoteSharedFolder + "/" + fName;
                                                            adbPullProc.command = [
                                                                "bash", "-c",
                                                                "mkdir -p \"$HOME/Downloads\" && adb pull \"" + remotePath + "\" \"$HOME/Downloads/\" && echo PULL_OK"
                                                            ];
                                                            statusNoticeText.text = "Pulling " + fName + " to ~/Downloads...";
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
                            width: columnsFlick.width
                            height: columnsFlick.height
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

                        // Secure helper (logic only – not a visible page)
                        Item {
                            id: secureTabHelper
                            width: 0
                            height: 0
                            visible: false

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
                            property bool batteryListCached: false

                            function fetchBatteryOptimization(forceRefresh) {
                                if (forceRefresh !== true && batteryListCached && batteryOptimizationModel.count > 0) {
                                    console.log("[BATTERY OPT]: Using cached list (" + batteryOptimizationModel.count + " apps)");
                                    return;
                                }
                                batteryOptimizationModel.clear();
                                batteryListCached = false;
                                isBatteryChecking = true;
                                console.log("[BATTERY OPT]: Scanning for non-restricted Google & third-party packages...");
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
                                let brand = phoneBrandFamily || "generic";
                                nukeStatus = "Starting Nuke Phone sequence...\n";
                                nukeStatus += "Phone: " + phoneManufacturer + " " + phoneModel +
                                              " | Android " + phoneAndroid + " (sdk " + phoneSdkInt +
                                              ") | profile=" + brand + "\n";
                                nukeStatus += "Thumbnails queued: " + thumbnailCount +
                                              " files (" + thumbnailSizeLabel + ")\n\n";

                                let dirs = thumbnailDirHints();
                                let dirRm = "";
                                for (let i = 0; i < dirs.length; i++) {
                                    dirRm += "echo '  dir " + dirs[i] + "'; adb shell rm -rf '" + dirs[i] + "'/* 2>/dev/null || true; ";
                                }
                                let thumb =
                                    "echo '=== 10. Removing media thumbnails ==='; " +
                                    "echo 'Profile: " + brand + "'; " +
                                    dirRm +
                                    "echo 'Generic .thumbnails sweep...'; " +
                                    "adb shell 'find /sdcard -type d -name .thumbnails 2>/dev/null' | tr -d '\\r' | while read -r d; do " +
                                    "  [ -z \"$d\" ] && continue; echo \"  $d\"; adb shell rm -rf \"$d\"/* 2>/dev/null || true; " +
                                    "done; " +
                                    "adb shell 'find /sdcard -type f \\( -name \"thumbdata*\" -o -name \"*.thumb\" \\) 2>/dev/null' | tr -d '\\r' | head -8000 | while read -r f; do " +
                                    "  [ -z \"$f\" ] && continue; adb shell rm -f \"$f\" 2>/dev/null || true; " +
                                    "done; " +
                                    "echo 'Thumbnail cleanup done.'; echo; " +
                                    "echo '=== Nuke Phone sequence finished ==='";

                                nukePhoneProc.command = ["bash", "-c", nukePhoneProc.coreScript + thumb];
                                nukePhoneProc.running = true;
                            }

                            Process {
                                id: nukePhoneProc
                                property string coreScript: "echo '=== 1. Disabling window animations ==='; " +
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
                                    "echo; "
                                command: []

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
                                        fetchThumbnailsProc.running = true;
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
                                // List only packages that are NOT effectively restricted.
                                // Restricted means:
                                //   - standby bucket is 45 (STANDBY_BUCKET_RESTRICTED), or
                                //   - both RUN_IN_BACKGROUND and RUN_ANY_IN_BACKGROUND are ignore/deny.
                                // Previous code checked bucket == 50 (wrong) and treated deviceidle
                                // whitelist as always-unrestricted, so restricted apps reappeared
                                // after every refresh.
                                command: [
                                    "bash", "-c",
                                    "pkgs=$(adb shell pm list packages 2>/dev/null | sed 's/package://' | tr -d '\\r' | sort -u); " +
                                    "for pkg in $pkgs; do " +
                                    "[ -z \"$pkg\" ] && continue; " +
                                    "bucket=$(adb shell am get-standby-bucket \"$pkg\" 2>/dev/null | tr -d '\\r' | tr -d ' '); " +
                                    "if [ \"$bucket\" = \"45\" ] || [ \"$bucket\" = \"restricted\" ]; then continue; fi; " +
                                    "if [ -n \"$bucket\" ] && [ \"$bucket\" -ge 45 ] 2>/dev/null; then continue; fi; " +
                                    "op1=$(adb shell appops get \"$pkg\" RUN_IN_BACKGROUND 2>/dev/null | tr -d '\\r'); " +
                                    "op2=$(adb shell appops get \"$pkg\" RUN_ANY_IN_BACKGROUND 2>/dev/null | tr -d '\\r'); " +
                                    "if echo \"$op1\" | grep -qiE 'ignore|deny' && echo \"$op2\" | grep -qiE 'ignore|deny'; then continue; fi; " +
                                    "echo \"$pkg\"; " +
                                    "done"
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        batteryOptimizationModel.clear();
                                        secureTabHelper.isBatteryChecking = false;
                                        let lines = text.trim().split("\n");

                                        let battItems = [];
                                        for (let i = 0; i < lines.length; i++) {
                                            let rawPkg = lines[i].trim();
                                            // Show preinstalled OEM apps (Camera, Calendar, Radio, …)
                                            // but hide only truly critical packages (phone, contacts, UI, …)
                                            if (rawPkg.length > 0 && !isBatteryListExcluded(rawPkg)) {
                                                battItems.push({
                                                    displayName: formatDisplayName(rawPkg),
                                                    rawPkg: rawPkg,
                                                    isToggledOn: true
                                                });
                                            }
                                        }
                                        battItems.sort(function(a, b) {
                                            return a.displayName.toLowerCase().localeCompare(b.displayName.toLowerCase());
                                        });
                                        for (let j = 0; j < battItems.length; j++) {
                                            batteryOptimizationModel.append(battItems[j]);
                                        }
                                        secureTabHelper.batteryListCached = true;
                                        console.log("[BATTERY OPT COMPLETE]: Cached " + batteryOptimizationModel.count + " non-restricted packages.");
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
                                property string pendingRemovePkg: ""

                                function runNext() {
                                    if (cmdQueue.length > 0) {
                                        let nextCmd = cmdQueue.shift();
                                        console.log("[BATTERY PROC EXEC]: " + nextCmd.join(" "));
                                        command = nextCmd;
                                        running = true;
                                    } else if (pendingRemovePkg !== "") {
                                        // Restriction queue finished – drop the package from the
                                        // "unrestricted" list so it does not reappear until it is
                                        // actually unrestricted again on a future refresh.
                                        let pkg = pendingRemovePkg;
                                        pendingRemovePkg = "";
                                        for (let i = batteryOptimizationModel.count - 1; i >= 0; i--) {
                                            if (batteryOptimizationModel.get(i).rawPkg === pkg) {
                                                batteryOptimizationModel.remove(i);
                                                console.log("[BATTERY OPT]: Removed restricted package from list:", pkg);
                                                break;
                                            }
                                        }
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

                        }   // end secureTabHelper (logic only)


                        // ===== Battery Optimization column =====
                        Item {
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Battery Optimization  <font color='#cd4f4c'>- Put apps in deep sleep</font>"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        textFormat: Text.RichText
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
                                        onClicked: secureTabHelper.fetchBatteryOptimization(true)
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

                                                    MouseArea {
                                                        anchors.left: parent.left
                                                        anchors.right: batterySwitch.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        onClicked: {
                                                            selectedAppInfo = {
                                                                pkg: model.rawPkg,
                                                                description: "Asking Gemini about battery restriction…",
                                                                safeToRemove: "…",
                                                                category: "Battery",
                                                                queryMode: "battery"
                                                            }
                                                            geminiDescProc.queryPkg(model.rawPkg, "battery", model.displayName)
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
                                                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                                            }
                                                        }

                                                        onToggled: {
                                                            model.isToggledOn = batterySwitch.checked
                                                            let pkg = model.rawPkg
                                                            // Invalidate cache so the next full refresh re-queries the device
                                                            secureTabHelper.batteryListCached = false
                                                            if (!batterySwitch.checked) {
                                                                // Put into deep sleep / restricted
                                                                restrictBatteryProc.pendingRemovePkg = pkg
                                                                restrictBatteryProc.cmdQueue = [
                                                                    // Remove from deviceidle whitelist if present (otherwise restriction can be ignored)
                                                                    ["adb", "shell", "dumpsys", "deviceidle", "whitelist", "-" + pkg],
                                                                    ["adb", "shell", "am", "set-standby-bucket", pkg, "restricted"],
                                                                    ["adb", "shell", "appops", "set", pkg, "RUN_IN_BACKGROUND", "ignore"],
                                                                    ["adb", "shell", "appops", "set", pkg, "RUN_ANY_IN_BACKGROUND", "ignore"]
                                                                ]
                                                            } else {
                                                                restrictBatteryProc.pendingRemovePkg = ""
                                                                restrictBatteryProc.cmdQueue = [
                                                                    ["adb", "shell", "am", "set-standby-bucket", pkg, "working_set"],
                                                                    ["adb", "shell", "appops", "set", pkg, "RUN_IN_BACKGROUND", "allow"],
                                                                    ["adb", "shell", "appops", "set", pkg, "RUN_ANY_IN_BACKGROUND", "allow"]
                                                                ]
                                                            }
                                                            restrictBatteryProc.runNext()
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: batteryOptimizationModel.count === 0 && !secureTabHelper.isBatteryChecking
                                        text: "No unrestricted Google / third-party apps found.\nPull to refresh or tap Refresh."
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
                        }

                        // ===== Nuke Phone column =====
                        Item {
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 10

                                Text {
                                    text: "Nuke Phone Output"
                                    color: "#dde5a2"
                                    font.bold: true
                                    font.family: "Monospace"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: {
                                        let brand = phoneBrandFamily || "generic"
                                        return "Phone profile: " + phoneManufacturer + " / " + phoneModel +
                                               " · Android " + phoneAndroid + " · " + brand
                                    }
                                    color: "#b0ac63"
                                    font.family: "Monospace"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    text: "Thumbnails on device: " + thumbnailCount +
                                          " files  ·  Total size: " + thumbnailSizeLabel
                                    color: "#ffcc66"
                                    font.family: "Monospace"
                                    font.pixelSize: 12
                                    font.bold: true
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
                                            text: secureTabHelper.nukeStatus.length > 0 ? secureTabHelper.nukeStatus : "Press “Nuke Phone” (button below) to run the full sequence.\n\n1. Hard-kill animation scale to 0\n2. Force GPU rendering + disable hardware overlays\n3. Cap background processes at 2\n4. Turn off adaptive battery completely\n5. Kill location services + Wi-Fi/BT scanning\n6. Trim global + third-party cache\n7. Force-stop every third-party app\n8. Disable brand bloat (Samsung/Microsoft when present)\n9. Delete all media thumbnails (count + size shown above)"
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



                        // ===== Secure column (12 security settings) =====
                        Item {
                            id: securePage
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ListModel {
                                id: secureFeaturesModel
                                ListElement {
                                    featureName: "Theft Detection Lock"
                                    featureDesc: "Lock phone on snatch motion (Android 15+)"
                                    adbAction: "android.settings.SECURITY_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Always-on VPN + Kill Switch"
                                    featureDesc: "VPN settings – enable Always-on & block without VPN"
                                    adbAction: "android.settings.VPN_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Identity Check"
                                    featureDesc: "Require biometrics for factory reset & sensitive actions"
                                    adbAction: "android.settings.SECURITY_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Strong Screen Lock"
                                    featureDesc: "Use 6-digit PIN or password (not 4-digit)"
                                    adbAction: "android.app.action.SET_NEW_PASSWORD"
                                }
                                ListElement {
                                    featureName: "Auto-lock under 30s"
                                    featureDesc: "Display / lock timeout – set to 30 seconds or less"
                                    adbAction: "android.settings.DISPLAY_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Messages Spam Protection"
                                    featureDesc: "Open Google Messages spam / phishing protection"
                                    adbAction: "messages_spam"
                                }
                                ListElement {
                                    featureName: "Install Unknown Apps"
                                    featureDesc: "Block sideloading – set all sources to Not allowed"
                                    adbAction: "android.settings.MANAGE_UNKNOWN_APP_SOURCES"
                                }
                                ListElement {
                                    featureName: "App Cleanup"
                                    featureDesc: "Review installed apps – remove unused ones"
                                    adbAction: "android.settings.APPLICATION_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Find Hub / Find My Device"
                                    featureDesc: "Enable offline finding & verify device is locatable"
                                    adbAction: "android.settings.SECURITY_SETTINGS"
                                }
                                ListElement {
                                    featureName: "OS Auto-updates"
                                    featureDesc: "System update – turn on auto-download"
                                    adbAction: "android.settings.SYSTEM_UPDATE_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Encrypted Backups"
                                    featureDesc: "Google Backup – confirm encrypted backup is on"
                                    adbAction: "android.settings.BACKUP_AND_RESET_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Lock-screen Notification Privacy"
                                    featureDesc: "Hide sensitive content on lock screen"
                                    adbAction: "android.settings.NOTIFICATION_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Notification Access"
                                    featureDesc: "Apps allowed to read or control notifications"
                                    adbAction: "android.settings.ACTION_NOTIFICATION_LISTENER_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Google Play Protect"
                                    featureDesc: "Scan apps & ensure Play Protect is enabled"
                                    adbAction: "play_protect"
                                }
                                ListElement {
                                    featureName: "Permission Manager"
                                    featureDesc: "Review location, camera, mic & other permissions"
                                    adbAction: "android.settings.PRIVACY_SETTINGS"
                                }
                                ListElement {
                                    featureName: "Developer Options"
                                    featureDesc: "Disable USB debugging when not needed"
                                    adbAction: "android.settings.APPLICATION_DEVELOPMENT_SETTINGS"
                                }
                            }

                            Process {
                                id: openSecureSettingProc
                                command: []
                            }

                            function openFeature(action) {
                                var cmd
                                if (action === "messages_spam") {
                                    cmd = ["adb", "shell", "am", "start", "-a", "android.intent.action.MAIN", "-n", "com.google.android.apps.messaging/.ui.ConversationListActivity"]
                                } else if (action === "play_protect") {
                                    cmd = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", "https://play.google.com/store/apps/details?id=com.android.vending"]
                                    // Prefer Play Protect settings when available
                                    cmd = ["adb", "shell", "am", "start", "-n", "com.google.android.gms/.security.settings.VerifyAppsSettingsActivity"]
                                } else if (action === "android.app.action.SET_NEW_PASSWORD") {
                                    cmd = ["adb", "shell", "am", "start", "-a", "android.app.action.SET_NEW_PASSWORD"]
                                } else {
                                    cmd = ["adb", "shell", "am", "start", "-a", action]
                                }
                                console.log("[SECURE] Opening:", cmd.join(" "))
                                openSecureSettingProc.command = cmd
                                openSecureSettingProc.running = true
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                Text {
                                    text: "Secure Phone – open each setting on the device"
                                    color: "#dde5a2"
                                    font.bold: true
                                    font.family: "Monospace"
                                    font.pixelSize: 13
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Based on essential Android security toggles. Tap Open to jump to that menu."
                                    color: "#b0ac63"
                                    font.family: "Monospace"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
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
                                        clip: true

                                        ListView {
                                            anchors.fill: parent
                                            model: secureFeaturesModel
                                            spacing: 6
                                            clip: true

                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 56
                                                color: Qt.rgba(0.22, 0.24, 0.21, 0.5)
                                                radius: 6
                                                border.color: "#3a3c2c"
                                                border.width: 1

                                                RowLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 8

                                                    ColumnLayout {
                                                        Layout.fillWidth: true
                                                        spacing: 2

                                                        Text {
                                                            text: model.featureName
                                                            color: "#b0ac63"
                                                            font.pixelSize: 12
                                                            font.family: "Monospace"
                                                            font.bold: true
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                        Text {
                                                            text: model.featureDesc
                                                            color: "#dde5a2"
                                                            font.pixelSize: 10
                                                            font.family: "Monospace"
                                                            opacity: 0.85
                                                            elide: Text.ElideRight
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    Button {
                                                        Layout.preferredWidth: 72
                                                        Layout.preferredHeight: 32
                                                        text: "Open"
                                                        font.pixelSize: 12
                                                        font.family: "Monospace"
                                                        scale: pressed ? 0.96 : 1.0
                                                        Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
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
                                                        onClicked: securePage.openFeature(model.adbAction)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }



                        // ===== Camera & Mic permissions column =====
                        Item {
                            id: camMicHelper
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ListModel {
                                id: camMicAppsModel
                            }

                            property bool isCamMicLoading: false
                            property bool camMicListCached: false

                            function fetchCamMicApps(forceRefresh) {
                                if (forceRefresh !== true && camMicListCached && camMicAppsModel.count > 0) {
                                    console.log("[CAM/MIC]: Using cached list (" + camMicAppsModel.count + " apps)");
                                    return;
                                }
                                camMicAppsModel.clear();
                                camMicListCached = false;
                                isCamMicLoading = true;
                                console.log("[CAM/MIC]: Scanning apps with CAMERA / MIC / LOCATION permission...");
                                fetchCamMicProc.running = true;
                            }

                            function setCamMicAllowed(pkg, allowed) {
                                // Any change invalidates cache so Refresh / Re-check re-reads the device
                                camMicListCached = false;
                                if (allowed) {
                                    camMicActionProc.cmdQueue = [
                                        ["adb", "shell", "pm", "grant", pkg, "android.permission.CAMERA"],
                                        ["adb", "shell", "pm", "grant", pkg, "android.permission.RECORD_AUDIO"],
                                        ["adb", "shell", "pm", "grant", pkg, "android.permission.ACCESS_FINE_LOCATION"],
                                        ["adb", "shell", "pm", "grant", pkg, "android.permission.ACCESS_COARSE_LOCATION"],
                                        ["adb", "shell", "appops", "set", pkg, "CAMERA", "allow"],
                                        ["adb", "shell", "appops", "set", pkg, "RECORD_AUDIO", "allow"],
                                        ["adb", "shell", "appops", "set", pkg, "FINE_LOCATION", "allow"],
                                        ["adb", "shell", "appops", "set", pkg, "COARSE_LOCATION", "allow"]
                                    ];
                                } else {
                                    camMicActionProc.cmdQueue = [
                                        ["adb", "shell", "pm", "revoke", pkg, "android.permission.CAMERA"],
                                        ["adb", "shell", "pm", "revoke", pkg, "android.permission.RECORD_AUDIO"],
                                        ["adb", "shell", "pm", "revoke", pkg, "android.permission.ACCESS_FINE_LOCATION"],
                                        ["adb", "shell", "pm", "revoke", pkg, "android.permission.ACCESS_COARSE_LOCATION"],
                                        ["adb", "shell", "appops", "set", pkg, "CAMERA", "deny"],
                                        ["adb", "shell", "appops", "set", pkg, "RECORD_AUDIO", "deny"],
                                        ["adb", "shell", "appops", "set", pkg, "FINE_LOCATION", "deny"],
                                        ["adb", "shell", "appops", "set", pkg, "COARSE_LOCATION", "deny"],
                                        ["adb", "shell", "appops", "set", pkg, "CAMERA", "ignore"],
                                        ["adb", "shell", "appops", "set", pkg, "RECORD_AUDIO", "ignore"],
                                        ["adb", "shell", "appops", "set", pkg, "FINE_LOCATION", "ignore"],
                                        ["adb", "shell", "appops", "set", pkg, "COARSE_LOCATION", "ignore"]
                                    ];
                                    // Remove from the visible list immediately
                                    for (let i = camMicAppsModel.count - 1; i >= 0; i--) {
                                        if (camMicAppsModel.get(i).rawPkg === pkg) {
                                            camMicAppsModel.remove(i);
                                            break;
                                        }
                                    }
                                }
                                camMicActionProc.runNext();
                            }

                            Process {
                                id: fetchCamMicProc
                                command: [
                                    "bash", "-c",
                                    "pkgs=$(adb shell pm list packages -3 2>/dev/null | sed 's/package://' | tr -d '\\r' | sort -u); " +
                                    "for pkg in $pkgs; do " +
                                    "  [ -z \"$pkg\" ] && continue; " +
                                    "  dump=$(adb shell dumpsys package \"$pkg\" 2>/dev/null | tr -d '\\r'); " +
                                    "  perms=\"\"; " +
                                    "  echo \"$dump\" | grep -qE 'android\\.permission\\.CAMERA.*(granted[=:] *true)' && perms=\"${perms}CAMERA,\"; " +
                                    "  echo \"$dump\" | grep -qE 'android\\.permission\\.RECORD_AUDIO.*(granted[=:] *true)' && perms=\"${perms}MIC,\"; " +
                                    "  echo \"$dump\" | grep -qE 'android\\.permission\\.ACCESS_(FINE|COARSE)_LOCATION.*(granted[=:] *true)' && perms=\"${perms}LOCATION,\"; " +
                                    "  if [ -n \"$perms\" ]; then " +
                                    "    perms=$(echo \"$perms\" | sed 's/,$//'); " +
                                    "    echo \"$pkg|$perms\"; " +
                                    "  fi; " +
                                    "done"
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        camMicAppsModel.clear();
                                        camMicHelper.isCamMicLoading = false;
                                        let lines = text.trim().split("\n");
                                        let items = [];
                                        for (let i = 0; i < lines.length; i++) {
                                            let line = lines[i].trim();
                                            if (line.length === 0) continue;
                                            let parts = line.split("|");
                                            let pkg = parts[0].trim();
                                            let mode = (parts[1] || "").trim();
                                            if (pkg.length === 0 || mode.length === 0) continue;
                                            if (isSystemCritical(pkg)) continue;
                                            items.push({
                                                displayName: formatDisplayName(pkg),
                                                rawPkg: pkg,
                                                accessMode: mode,
                                                isAllowed: true
                                            });
                                        }
                                        items.sort(function(a, b) {
                                            return a.displayName.toLowerCase().localeCompare(b.displayName.toLowerCase());
                                        });
                                        for (let j = 0; j < items.length; j++) {
                                            camMicAppsModel.append(items[j]);
                                        }
                                        camMicHelper.camMicListCached = true;
                                        console.log("[CAM/MIC COMPLETE]: Cached " + camMicAppsModel.count + " apps with camera/mic access");
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        camMicHelper.isCamMicLoading = false;
                                        if (text.trim().length > 0) {
                                            console.log("[CAM/MIC ERROR]: " + text.trim().substring(0, 300));
                                        }
                                    }
                                }
                            }

                            Process {
                                id: camMicActionProc
                                property var cmdQueue: []
                                function runNext() {
                                    if (cmdQueue.length > 0) {
                                        let nextCmd = cmdQueue.shift();
                                        console.log("[CAM/MIC ACTION]: " + nextCmd.join(" "));
                                        command = nextCmd;
                                        running = true;
                                    }
                                }
                                onExited: function(code) {
                                    runNext();
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "Camera · Mic · Location Access"
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
                                        onClicked: camMicHelper.fetchCamMicApps(true)
                                    }
                                }

                                Text {
                                    text: "Apps with camera, microphone, and/or location permission. Toggle off to deny all three."
                                    color: "#b0ac63"
                                    font.family: "Monospace"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
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
                                        visible: camMicAppsModel.count > 0
                                        clip: true

                                        ListView {
                                            anchors.fill: parent
                                            model: camMicAppsModel
                                            spacing: 6
                                            clip: true

                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 52
                                                color: Qt.rgba(0.22, 0.24, 0.21, 0.5)
                                                radius: 6
                                                border.color: "#3a3c2c"
                                                border.width: 1

                                                Item {
                                                    anchors.fill: parent
                                                    anchors.margins: 8

                                                    ColumnLayout {
                                                        anchors.left: parent.left
                                                        anchors.right: camMicSwitch.left
                                                        anchors.rightMargin: 8
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        spacing: 2

                                                        RowLayout {
                                                            Layout.fillWidth: true
                                                            spacing: 6
                                                            // Green = currently has camera/mic permission
                                                            Rectangle {
                                                                width: 10
                                                                height: 10
                                                                radius: 5
                                                                color: model.isAllowed ? "#3dcc6d" : "#666666"
                                                                border.color: model.isAllowed ? "#88ffaa" : "#444"
                                                                border.width: 1
                                                                Layout.alignment: Qt.AlignVCenter
                                                            }
                                                            Text {
                                                                text: model.displayName
                                                                color: "#b0ac63"
                                                                font.pixelSize: 12
                                                                font.family: "Monospace"
                                                                font.bold: true
                                                                elide: Text.ElideMiddle
                                                                Layout.fillWidth: true
                                                            }
                                                        }
                                                        Text {
                                                            text: model.rawPkg + "  ·  " + String(model.accessMode).split(",").join(" · ")
                                                            color: "#dde5a2"
                                                            font.pixelSize: 10
                                                            font.family: "Monospace"
                                                            opacity: 0.85
                                                            elide: Text.ElideMiddle
                                                            Layout.fillWidth: true
                                                        }
                                                    }

                                                    MouseArea {
                                                        anchors.left: parent.left
                                                        anchors.right: camMicSwitch.left
                                                        anchors.top: parent.top
                                                        anchors.bottom: parent.bottom
                                                        onClicked: {
                                                            let extra = model.accessMode ? ("Permissions: " + model.accessMode) : ""
                                                            selectedAppInfo = {
                                                                pkg: model.rawPkg,
                                                                description: "Asking Gemini about camera/mic/location permissions…",
                                                                safeToRemove: "…",
                                                                category: "Cam/Mic",
                                                                queryMode: "cammic"
                                                            }
                                                            geminiDescProc.queryPkg(model.rawPkg, "cammic", extra)
                                                        }
                                                    }

                                                    Switch {
                                                        id: camMicSwitch
                                                        anchors.right: parent.right
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        checked: model.isAllowed

                                                        indicator: Rectangle {
                                                            implicitWidth: 44
                                                            implicitHeight: 22
                                                            radius: 11
                                                            color: camMicSwitch.checked ? "#2a2c22" : "#1b1c1e"
                                                            border.color: camMicSwitch.checked ? "#b0ac63" : "#444"
                                                            border.width: 1
                                                            Rectangle {
                                                                x: camMicSwitch.checked ? parent.width - width - 2 : 2
                                                                y: 2
                                                                width: 18
                                                                height: 18
                                                                radius: 9
                                                                color: camMicSwitch.checked ? "#dde5a2" : "#666666"
                                                                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                                                            }
                                                        }

                                                        onToggled: {
                                                            model.isAllowed = camMicSwitch.checked;
                                                            camMicHelper.setCamMicAllowed(model.rawPkg, camMicSwitch.checked);
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: camMicAppsModel.count === 0 && !camMicHelper.isCamMicLoading
                                        text: "No apps with camera/mic access found.\\nTap Refresh to scan again."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: camMicHelper.isCamMicLoading
                                        text: "Scanning camera & microphone permissions..."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                    }
                                }
                            }
                        }



                        // ===== App Connections (live TCP) =====
                        Item {
                            id: appConnHelper
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ListModel {
                                id: appConnModel
                            }

                            property bool isMonitoring: false
                            property string statusText: "Open this tab to start monitoring."
                            property var seenThisCycle
                            property int cycleCount: 0

                            function startMonitoring() {
                                console.log("[CONN DEBUG] startMonitoring() called, wasMonitoring=" + appConnHelper.isMonitoring)
                                if (appConnHelper.isMonitoring) {
                                    console.log("[CONN DEBUG] already monitoring – forcing another sample")
                                    if (!connProcess.running)
                                        connProcess.running = true
                                    if (!devtoolsProcess.running)
                                        devtoolsProcess.running = true
                                    return
                                }
                                appConnModel.clear()
                                appConnHelper.seenThisCycle = {}
                                appConnHelper.cycleCount = 0
                                appConnHelper.statusText = "Starting DevTools forward + connection monitor..."
                                appConnHelper.isMonitoring = true
                                // Forward Chromium DevTools socket (Chrome / Brave / many WebViews)
                                adbForwardProc.running = true
                                connProcess.running = true
                                console.log("[CONN DEBUG] Monitoring started")
                            }

                            function stopMonitoring() {
                                if (!appConnHelper.isMonitoring) return
                                connProcess.running = false
                                devtoolsProcess.running = false
                                connSampleTimer.stop()
                                devtoolsTimer.stop()
                                appConnHelper.isMonitoring = false
                                appConnHelper.statusText = "Monitoring stopped."
                                console.log("[CONN DEBUG] Monitoring stopped")
                            }

                            function upsertBrowserTab(title, url, tabId) {
                                if (!url || url.length === 0) return
                                if (url.indexOf("chrome://") === 0 || url.indexOf("brave://") === 0 ||
                                    url.indexOf("about:") === 0 || url.indexOf("devtools://") === 0)
                                    return
                                let key = "browser|" + tabId + "|" + url
                                if (!appConnHelper.seenThisCycle)
                                    appConnHelper.seenThisCycle = {}
                                appConnHelper.seenThisCycle[key] = true

                                let host = ""
                                let schemeIdx = url.indexOf("://")
                                if (schemeIdx >= 0) {
                                    let rest = url.substring(schemeIdx + 3)
                                    let slash = rest.indexOf("/")
                                    let colon = rest.indexOf(":")
                                    let cut = rest.length
                                    if (slash >= 0) cut = Math.min(cut, slash)
                                    if (colon >= 0) cut = Math.min(cut, colon)
                                    host = rest.substring(0, cut)
                                }

                                for (let i = 0; i < appConnModel.count; i++) {
                                    let row = appConnModel.get(i)
                                    if (row.kind === "browser" && row.tabId === tabId) {
                                        appConnModel.setProperty(i, "displayName", title && title.length ? title : host)
                                        appConnModel.setProperty(i, "endpoint", url)
                                        appConnModel.setProperty(i, "hostname", host)
                                        appConnModel.setProperty(i, "lastSeen", appConnHelper.cycleCount)
                                        return
                                    }
                                }
                                appConnModel.append({
                                    displayName: (title && title.length) ? title : (host || "Browser tab"),
                                    rawPkg: "browser",
                                    endpoint: url,
                                    ipAddr: "",
                                    portNum: "",
                                    hostname: host,
                                    lastSeen: appConnHelper.cycleCount,
                                    kind: "browser",
                                    tabId: tabId,
                                    isSystem: false
                                })
                            }

                            function parseDevtoolsJson(raw) {
                                try {
                                    let data = JSON.parse(raw)
                                    if (!data || !data.length) {
                                        console.log("[CONN DEBUG] DevTools JSON empty or not a list")
                                        return 0
                                    }
                                    let n = 0
                                    for (let i = 0; i < data.length; i++) {
                                        let tab = data[i]
                                        if (!tab) continue
                                        if (tab.type && tab.type !== "page" && tab.type !== "app") continue
                                        let title = tab.title || ""
                                        let url = tab.url || ""
                                        let id = String(tab.id || i)
                                        if (url && url.length > 0) {
                                            upsertBrowserTab(title, url, id)
                                            n++
                                        }
                                    }
                                    return n
                                } catch (e) {
                                    console.log("[CONN DEBUG] DevTools JSON parse error: " + e)
                                    return 0
                                }
                            }

                            // adb forward for Chromium remote debugging
                            Process {
                                id: adbForwardProc
                                command: ["adb", "forward", "tcp:9222", "localabstract:chrome_devtools_remote"]
                                running: false
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        console.log("[CONN DEBUG] adb forward stdout: " + text.trim())
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length)
                                            console.log("[CONN DEBUG] adb forward stderr: " + text.trim())
                                    }
                                }
                                onExited: function(code) {
                                    console.log("[CONN DEBUG] adb forward exited code=" + code)
                                    // Start polling DevTools JSON
                                    if (appConnHelper.isMonitoring)
                                        devtoolsProcess.running = true
                                }
                            }

                            Process {
                                id: devtoolsProcess
                                running: false
                                command: ["curl", "-s", "--max-time", "2", "http://127.0.0.1:9222/json"]
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        if (!appConnHelper.isMonitoring) return
                                        let raw = text.trim()
                                        console.log("[CONN DEBUG] DevTools json length=" + raw.length)
                                        if (raw.length > 0)
                                            console.log("[CONN DEBUG] DevTools json head: " + raw.substring(0, 200))
                                        let n = appConnHelper.parseDevtoolsJson(raw)
                                        appConnHelper.statusText = "Live · " + appConnModel.count + " item(s) · " + n + " browser tab(s)"
                                        if (appConnHelper.isMonitoring)
                                            devtoolsTimer.restart()
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length)
                                            console.log("[CONN DEBUG] DevTools curl stderr: " + text.trim().substring(0, 200))
                                    }
                                }
                                onExited: function(code) {
                                    if (appConnHelper.isMonitoring && !devtoolsTimer.running)
                                        devtoolsTimer.restart()
                                }
                            }

                            Timer {
                                id: devtoolsTimer
                                interval: 2000
                                repeat: false
                                onTriggered: {
                                    if (appConnHelper.isMonitoring && !devtoolsProcess.running)
                                        devtoolsProcess.running = true
                                }
                            }

                            function resolveHost(ip) {
                                // Quick private-range label; reverse DNS is async via hostResolveProc
                                if (ip.indexOf("10.") === 0 || ip.indexOf("192.168.") === 0 ||
                                    ip.indexOf("172.") === 0 || ip === "127.0.0.1") {
                                    return "(local)"
                                }
                                return ""
                            }

                            function updateConnection(pkg, endpoint, proto) {
                                if (!proto) proto = "tcp"
                                let ip = endpoint.split(":")[0] || endpoint
                                let port = endpoint.indexOf(":") >= 0 ? endpoint.split(":")[1] : ""
                                let netName = ""
                                // ss+whois lines look like: net:GOOGLE|ip:0|ss
                                if (pkg.indexOf("net:") === 0) {
                                    netName = pkg.substring(4).trim()
                                    pkg = "net:" + netName
                                }
                                let key = pkg + "|" + endpoint
                                if (!appConnHelper.seenThisCycle)
                                    appConnHelper.seenThisCycle = {}
                                appConnHelper.seenThisCycle[key] = true

                                for (let i = 0; i < appConnModel.count; i++) {
                                    let row = appConnModel.get(i)
                                    if (row.rawPkg === pkg && row.endpoint === endpoint) {
                                        appConnModel.setProperty(i, "lastSeen", appConnHelper.cycleCount)
                                        if (netName.length > 0)
                                            appConnModel.setProperty(i, "hostname", netName)
                                        return
                                    }
                                }

                                let hostHint = netName.length > 0 ? netName : resolveHost(ip)
                                let sys = isSystemNetworkService(pkg) || pkg.indexOf("net:") === 0 || pkg === "system" || pkg === "unknown"
                                let dname
                                if (netName.length > 0) {
                                    dname = "[SYSTEM] " + netName
                                    sys = true
                                } else {
                                    dname = formatDisplayName(pkg)
                                    if (sys) dname = "[SYSTEM] " + dname
                                    if (proto && proto !== "tcp" && proto !== "ss")
                                        dname = dname + " [" + proto.toUpperCase() + "]"
                                }
                                appConnModel.append({
                                    displayName: dname,
                                    rawPkg: pkg,
                                    endpoint: endpoint,
                                    ipAddr: ip,
                                    portNum: port,
                                    hostname: hostHint,
                                    lastSeen: appConnHelper.cycleCount,
                                    kind: "tcp",
                                    tabId: "",
                                    isSystem: sys
                                })

                                // whois already done for ss rows; only enqueue DNS for package rows
                                if (netName.length === 0 && hostHint === "" && ip.length > 0) {
                                    hostResolveProc.enqueue(ip, pkg, endpoint)
                                }
                            }

                            function pruneStale() {
                                // Browser tabs: keep a bit longer; TCP rows keep ~20s so
                                // short downloads (F-Droid etc.) stay visible
                                for (let i = appConnModel.count - 1; i >= 0; i--) {
                                    let row = appConnModel.get(i)
                                    let maxAge = (row.kind === "browser") ? 12 : 20
                                    if (appConnHelper.cycleCount - row.lastSeen > maxAge) {
                                        appConnModel.remove(i)
                                    }
                                }
                            }

                            // Reverse-DNS queue (host-side)
                            Process {
                                id: hostResolveProc
                                property var queue: []
                                property var pendingKey: ""

                                function enqueue(ip, pkg, endpoint) {
                                    let key = pkg + "|" + endpoint
                                    // Avoid duplicate lookups
                                    for (let i = 0; i < queue.length; i++) {
                                        if (queue[i].key === key) return
                                    }
                                    queue.push({ ip: ip, pkg: pkg, endpoint: endpoint, key: key })
                                    if (!running) runNext()
                                }

                                function runNext() {
                                    if (queue.length === 0) {
                                        pendingKey = ""
                                        return
                                    }
                                    let job = queue.shift()
                                    pendingKey = job.key
                                    // getent / dig / host – first that works
                                    command = [
                                        "bash", "-c",
                                        "IP=\"" + job.ip + "\"; " +
                                        "H=$(whois \"$IP\" 2>/dev/null | grep -iE '^(netname|NetName|org-name|OrgName):' | head -n 1 | sed 's/^[^:]*:[[:space:]]*//'); " +
                                        "if [ -z \"$H\" ]; then H=$(getent hosts \"$IP\" 2>/dev/null | awk '{print $2; exit}'); fi; " +
                                        "if [ -z \"$H\" ]; then H=$(dig +short -x \"$IP\" 2>/dev/null | head -1 | sed 's/\\.$//'); fi; " +
                                        "if [ -z \"$H\" ]; then H=$(host \"$IP\" 2>/dev/null | awk '/domain name pointer/{print $5; exit}' | sed 's/\\.$//'); fi; " +
                                        "echo \"" + job.pkg + "|" + job.endpoint + "|${H:-}\""
                                    ]
                                    running = true
                                }

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let line = text.trim()
                                        if (line.length > 0) {
                                            let p = line.split("|")
                                            if (p.length >= 3) {
                                                let pkg = p[0], ep = p[1], host = p[2]
                                                if (host && host.length > 0) {
                                                    for (let i = 0; i < appConnModel.count; i++) {
                                                        let row = appConnModel.get(i)
                                                        if (row.rawPkg === pkg && row.endpoint === ep) {
                                                            appConnModel.setProperty(i, "hostname", host)
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        hostResolveProc.runNext()
                                    }
                                }
                                onExited: function() { /* runNext from stdout */ }
                            }

                            // Live connection sampler on device
                            Process {
                                id: connProcess
                                running: false
                                // Exact device-side awk that works in the user's terminal
                                command: [
                                    "bash", "-c",
                                    "set +e; " +
                                    "for ip in $(adb shell ss -tun 2>/dev/null | awk 'NR>1 {print $6}' | sed 's/\\[//g' | sed 's/\\]//g' | sed 's/::ffff://g' | sed 's/:[0-9]*$//' | sort -u); do " +
                                    "  if [ -n \"$ip\" ] && ! echo \"$ip\" | grep -qE '^(192\\.168\\.|10\\.|172\\.(1[6-9]|2[0-9]|3[0-1])\\.|127\\.|0\\.)'; then " +
                                    "    net=$(whois \"$ip\" 2>/dev/null | grep -iE 'NetName:' | head -n 1 | sed 's/^[^:]*:[[:space:]]*//'); " +
                                    "    [ -z \"$net\" ] && net=$(whois \"$ip\" 2>/dev/null | grep -iE '^(netname|org-name|OrgName):' | head -n 1 | sed 's/^[^:]*:[[:space:]]*//'); " +
                                    "    [ -z \"$net\" ] && net=\"external\"; " +
                                    "    echo \"net:$net|$ip:0|ss\"; " +
                                    "  fi; " +
                                    "done; " +
                                    "adb shell \"awk '" +
                                    "BEGIN { " +
                                    "  while ((\\\"pm list packages -U\\\" | getline line) > 0) { " +
                                    "    if (index(line, \\\"package:\\\") == 1) { " +
                                    "      sub(/^package:/, \\\"\\\", line); " +
                                    "      split(line, parts, \\\" uid:\\\"); " +
                                    "      uid_to_pkg[parts[2]] = parts[1]; " +
                                    "    } " +
                                    "  } " +
                                    "  close(\\\"pm list packages -U\\\"); " +
                                    "  uid_to_pkg[\\\"0\\\"]=\\\"root\\\"; uid_to_pkg[\\\"1000\\\"]=\\\"system\\\"; uid_to_pkg[\\\"2000\\\"]=\\\"shell\\\"; " +
                                    "} " +
                                    "function hex_to_ip(h, a,b,c,d) { " +
                                    "  if (length(h)!=8) return h; " +
                                    "  a=(\\\"0x\\\" substr(h,7,2))+0; b=(\\\"0x\\\" substr(h,5,2))+0; " +
                                    "  c=(\\\"0x\\\" substr(h,3,2))+0; d=(\\\"0x\\\" substr(h,1,2))+0; " +
                                    "  return a \\\".\\\" b \\\".\\\" c \\\".\\\" d; " +
                                    "} " +
                                    "function hex_port(h) { return (\\\"0x\\\" h)+0; } " +
                                    "FILENAME ~ /tcp/ && NR>1 && (\\$4==\\\"01\\\" || \\$4==\\\"02\\\") { " +
                                    "  split(\\$3, rem, \\\":\\\"); if (length(rem)<2) next; " +
                                    "  r_ip=hex_to_ip(rem[1]); r_port=hex_port(rem[2]); " +
                                    "  if (r_ip==\\\"0.0.0.0\\\" || r_ip==\\\"127.0.0.1\\\") next; " +
                                    "  uid=\\$8; pkg=uid_to_pkg[uid]; if (!pkg) pkg=\\\"UID:\\\" uid; " +
                                    "  print pkg \\\"|\\\" r_ip \\\":\\\" r_port \\\"|tcp\\\"; " +
                                    "} " +
                                    "FILENAME ~ /udp/ && NR>1 { " +
                                    "  split(\\$3, rem, \\\":\\\"); if (length(rem)<2) next; " +
                                    "  if (rem[1]==\\\"00000000\\\") next; " +
                                    "  r_ip=hex_to_ip(rem[1]); r_port=hex_port(rem[2]); " +
                                    "  if (r_ip==\\\"0.0.0.0\\\" || r_ip==\\\"127.0.0.1\\\") next; " +
                                    "  uid=\\$8; pkg=uid_to_pkg[uid]; if (!pkg) pkg=\\\"UID:\\\" uid; " +
                                    "  print pkg \\\"|\\\" r_ip \\\":\\\" r_port \\\"|udp\\\"; " +
                                    "} " +
                                    "' /proc/net/tcp /proc/net/tcp6 /proc/net/udp /proc/net/udp6 2>/dev/null\""
                                ]

                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        console.log("[CONN DEBUG] stdout finished, length=" + text.length)
                                        if (text.length > 0) {
                                            console.log("[CONN DEBUG] stdout raw (first 800 chars):\\n" + text.substring(0, 800))
                                        } else {
                                            console.log("[CONN DEBUG] stdout EMPTY")
                                        }
                                        if (!appConnHelper.isMonitoring) {
                                            console.log("[CONN DEBUG] ignoring stdout – not monitoring")
                                            return
                                        }
                                        appConnHelper.cycleCount += 1
                                        appConnHelper.seenThisCycle = {}
                                        let raw = text.trim()
                                        let cleaned = raw.split("\r").join("");
                                        let lines = cleaned.length > 0 ? cleaned.split(String.fromCharCode(10)) : []
                                        let n = 0
                                        let uniquePkgs = []
                                        for (let i = 0; i < lines.length; i++) {
                                            let line = lines[i].trim()
                                            if (line.length === 0) continue
                                            let parts = line.split("|")
                                            if (parts.length < 2) {
                                                console.log("[CONN DEBUG] skip bad line: " + line)
                                                continue
                                            }
                                            let pkg = parts[0].trim()
                                            let ep = parts[1].trim()
                                            let proto = parts.length > 2 ? parts[2].trim() : "tcp"
                                            if (pkg === "root" || pkg === "shell") continue
                                            appConnHelper.updateConnection(pkg, ep, proto)
                                            n++
                                            if (uniquePkgs.indexOf(pkg) < 0) uniquePkgs.push(pkg)
                                        }
                                        appConnHelper.pruneStale()
                                        appConnHelper.statusText = "Live · " + appConnModel.count + " item(s) · TCP cycle " + appConnHelper.cycleCount
                                        console.log("[CONN DEBUG] TCP cycle " + appConnHelper.cycleCount + " lines=" + n + " pkgs=[" + uniquePkgs.join(", ") + "] model=" + appConnModel.count)
                                        if (appConnHelper.isMonitoring)
                                            connSampleTimer.restart()
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length > 0) {
                                            console.log("[CONN DEBUG] stderr: " + text.trim().substring(0, 500))
                                        }
                                    }
                                }
                                onExited: function(code, status) {
                                    console.log("[CONN DEBUG] process exited code=" + code + " status=" + status + " monitoring=" + appConnHelper.isMonitoring)
                                    if (appConnHelper.isMonitoring && !connSampleTimer.running)
                                        connSampleTimer.restart()
                                }
                                onRunningChanged: {
                                    console.log("[CONN DEBUG] running=" + running)
                                }
                            }

                            Timer {
                                id: connSampleTimer
                                interval: 4000
                                repeat: false
                                onTriggered: {
                                    if (appConnHelper.isMonitoring && !connProcess.running)
                                        connProcess.running = true
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 8

                                RowLayout {
                                    Layout.fillWidth: true
                                    Text {
                                        text: "App Connections + Browser URLs"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                    }
                                    Text {
                                        text: appConnHelper.isMonitoring ? "● LIVE" : "○ stopped"
                                        color: appConnHelper.isMonitoring ? "#3dcc6d" : "#888888"
                                        font.family: "Monospace"
                                        font.pixelSize: 11
                                        font.bold: true
                                    }

                                }

                                Text {
                                    text: appConnHelper.statusText
                                    color: "#b0ac63"
                                    font.family: "Monospace"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
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
                                        visible: appConnModel.count > 0
                                        clip: true

                                        ListView {
                                            anchors.fill: parent
                                            model: appConnModel
                                            spacing: 6
                                            clip: true

                                            delegate: Rectangle {
                                                width: ListView.view.width
                                                height: 52
                                                color: model.isSystem ? Qt.rgba(0.35, 0.12, 0.12, 0.55) : Qt.rgba(0.22, 0.24, 0.21, 0.5)
                                                radius: 6
                                                border.color: model.isSystem ? "#aa4444" : "#3a3c2c"
                                                border.width: 1

                                                MouseArea {
                                                    anchors.fill: parent
                                                    onClicked: {
                                                        let label = model.displayName || model.rawPkg || ""
                                                        let ip = model.ipAddr || ""
                                                        let ep = model.endpoint || ""
                                                        let host = model.hostname || ""
                                                        // Stable id so Gemini response can match selectedAppInfo.pkg
                                                        let id = (model.rawPkg || label) + " @ " + (ep || ip || "unknown")
                                                        let ctx = "Label: " + label + "\n"
                                                        ctx += "Package: " + (model.rawPkg || "") + "\n"
                                                        ctx += "Endpoint: " + ep + "\n"
                                                        if (ip) ctx += "IP: " + ip + "\n"
                                                        if (host) ctx += "Hostname/Org: " + host + "\n"
                                                        if (model.kind === "browser") ctx += "Type: browser page/URL\n"
                                                        selectedAppInfo = {
                                                            pkg: id,
                                                            description: "Asking Gemini about this network connection…",
                                                            safeToRemove: "…",
                                                            category: "Connection",
                                                            queryMode: "connection"
                                                        }
                                                        console.log("[CONN GEMINI] query id=" + id)
                                                        geminiDescProc.queryPkg(id, "connection", ctx)
                                                    }
                                                }

                                                ColumnLayout {
                                                    anchors.fill: parent
                                                    anchors.margins: 8
                                                    spacing: 2

                                                    Text {
                                                        text: {
                                                            if (model.kind === "browser")
                                                                return "🌐  " + model.displayName
                                                            if (model.isSystem)
                                                                return model.displayName + "  (" + model.rawPkg + ")"
                                                            return model.displayName + "  (" + model.rawPkg + ")"
                                                        }
                                                        color: model.kind === "browser" ? "#7ec8ff" : (model.isSystem ? "#ff6b6b" : "#b0ac63")
                                                        font.pixelSize: 12
                                                        font.family: "Monospace"
                                                        font.bold: true
                                                        elide: Text.ElideMiddle
                                                        Layout.fillWidth: true
                                                    }
                                                    Text {
                                                        text: {
                                                            if (model.kind === "browser")
                                                                return model.endpoint
                                                            let h = model.hostname && model.hostname.length > 0 ? model.hostname + "  ·  " : ""
                                                            return h + model.endpoint
                                                        }
                                                        color: "#dde5a2"
                                                        font.pixelSize: 11
                                                        font.family: "Monospace"
                                                        opacity: 0.9
                                                        elide: Text.ElideMiddle
                                                        Layout.fillWidth: true
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: appConnModel.count === 0
                                        text: appConnHelper.isMonitoring
                                              ? "Waiting for established TCP connections…\nOpen Chrome or any app that uses the network."
                                              : "Switch to this tab to start monitoring."
                                        color: "#b0ac63"
                                        font.pixelSize: 12
                                        font.family: "Monospace"
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                }
                            }
                        }



                        // ===== Install apps column =====
                        Item {
                            width: columnsFlick.width
                            height: columnsFlick.height

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 16
                                spacing: 16

                                Text {
                                    text: "Install Apps"
                                    color: "#dde5a2"
                                    font.bold: true
                                    font.family: "Monospace"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }

                                Text {
                                    text: "Install useful apps on the connected phone."
                                    color: "#b0ac63"
                                    font.family: "Monospace"
                                    font.pixelSize: 11
                                    Layout.fillWidth: true
                                    wrapMode: Text.WordWrap
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    color: "#1a1c18"
                                    radius: 8
                                    border.color: "#555839"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: "F-Droid"
                                                color: "#b0ac63"
                                                font.bold: true
                                                font.family: "Monospace"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: isFDroidInstalled ? "Installed – tap to open" : "Free/open-source app store (sideload APK)"
                                                color: "#dde5a2"
                                                font.family: "Monospace"
                                                font.pixelSize: 10
                                                opacity: 0.85
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Button {
                                            Layout.preferredWidth: 110
                                            Layout.preferredHeight: 36
                                            text: installFDroidProc.running ? "Installing…" : (isFDroidInstalled ? "Open" : "Install")
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                            enabled: !installFDroidProc.running && !openFDroidProc.running
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
                                            background: Rectangle {
                                                radius: 6
                                                color: parent.enabled ? (parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30") : "#252627"
                                                border.color: Qt.darker("#555839", 1.2)
                                                border.width: 1
                                            }
                                            contentItem: Text {
                                                text: parent.text
                                                font: parent.font
                                                color: parent.enabled ? "#dde5a2" : "#666"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (isFDroidInstalled) openFDroidProc.running = true
                                                else installFDroidProc.running = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    color: "#1a1c18"
                                    radius: 8
                                    border.color: "#555839"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: "CX File Explorer"
                                                color: "#b0ac63"
                                                font.bold: true
                                                font.family: "Monospace"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: "Opens Google Play Store page for CX File Explorer"
                                                color: "#dde5a2"
                                                font.family: "Monospace"
                                                font.pixelSize: 10
                                                opacity: 0.85
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Button {
                                            Layout.preferredWidth: 110
                                            Layout.preferredHeight: 36
                                            text: "Play Store"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
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
                                                // CX File Explorer package on Play Store
                                                pendingPlayStorePkg = "com.cxinventor.file.explorer"
                                                playStoreConnectCheckProc.running = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    color: "#1a1c18"
                                    radius: 8
                                    border.color: "#555839"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: "Total Commander"
                                                color: "#b0ac63"
                                                font.bold: true
                                                font.family: "Monospace"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: "Opens Google Play Store for Total Commander file manager"
                                                color: "#dde5a2"
                                                font.family: "Monospace"
                                                font.pixelSize: 10
                                                opacity: 0.85
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Button {
                                            Layout.preferredWidth: 110
                                            Layout.preferredHeight: 36
                                            text: "Play Store"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
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
                                                pendingPlayStorePkg = "com.ghisler.android.TotalCommander"
                                                playStoreConnectCheckProc.running = true
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 72
                                    color: "#1a1c18"
                                    radius: 8
                                    border.color: "#555839"
                                    border.width: 1

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 12
                                        spacing: 12

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            Text {
                                                text: "VLC"
                                                color: "#b0ac63"
                                                font.bold: true
                                                font.family: "Monospace"
                                                font.pixelSize: 13
                                            }
                                            Text {
                                                text: "Opens Google Play Store for VLC media player"
                                                color: "#dde5a2"
                                                font.family: "Monospace"
                                                font.pixelSize: 10
                                                opacity: 0.85
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
                                        }

                                        Button {
                                            Layout.preferredWidth: 110
                                            Layout.preferredHeight: 36
                                            text: "Play Store"
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
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
                                                pendingPlayStorePkg = "org.videolan.vlc"
                                                playStoreConnectCheckProc.running = true
                                            }
                                        }
                                    }
                                }

                                Item { Layout.fillHeight: true }
                            }
                        }

                        // ===== Video tab =====
                        Item {
                            id: videoTabHelper
                            width: columnsFlick.width
                            height: columnsFlick.height

                            property string currentVideo: ""

                            function playVideo(name) {
                                let path = Qt.resolvedUrl("Videos/" + name + ".mp4")
                                currentVideo = name
                                videoStatusLabel.text = "Playing: " + name + ".mp4"
                                console.log("[VIDEO] play " + path)
                                videoPlayer.stop()
                                videoPlayer.source = path
                                videoPlayer.play()
                            }

                            function stopVideo() {
                                videoPlayer.stop()
                                currentVideo = ""
                                videoStatusLabel.text = "Choose a video button above."
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 6
                                spacing: 6

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Text {
                                        text: "Video"
                                        color: "#dde5a2"
                                        font.bold: true
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                    }

                                    Item { Layout.fillWidth: true }

                                    Repeater {
                                        model: ["Admin", "Pairing", "Tracker"]
                                        Button {
                                            Layout.preferredWidth: 90
                                            Layout.preferredHeight: 32
                                            text: modelData
                                            font.pixelSize: 13
                                            font.family: "Monospace"
                                            font.bold: videoTabHelper.currentVideo === modelData.toLowerCase()
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
                                            background: Rectangle {
                                                radius: 8
                                                color: videoTabHelper.currentVideo === modelData.toLowerCase()
                                                       ? "#4a5538" : (parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30")
                                                border.color: videoTabHelper.currentVideo === modelData.toLowerCase()
                                                              ? "#b0ac63" : Qt.darker("#555839", 1.2)
                                                border.width: 1
                                            }
                                            contentItem: Text {
                                                text: parent.text
                                                font: parent.font
                                                color: "#dde5a2"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: videoTabHelper.playVideo(modelData.toLowerCase())
                                        }
                                    }

                                    Button {
                                        Layout.preferredWidth: 64
                                        Layout.preferredHeight: 32
                                        text: "Stop"
                                        font.pixelSize: 11
                                        font.family: "Monospace"
                                        enabled: videoTabHelper.currentVideo !== ""
                                        background: Rectangle {
                                            radius: 6
                                            color: parent.enabled ? (parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30") : "#252627"
                                            border.color: Qt.darker("#555839", 1.2)
                                            border.width: 1
                                        }
                                        contentItem: Text {
                                            text: parent.text
                                            font: parent.font
                                            color: parent.enabled ? "#dde5a2" : "#666"
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                        onClicked: videoTabHelper.stopVideo()
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    color: "#0a0b0a"
                                    radius: 6
                                    border.color: "#555839"
                                    border.width: 1
                                    clip: true

                                    VideoOutput {
                                        id: videoOutput
                                        anchors.fill: parent
                                        anchors.margins: 0
                                        // Fill the panel – crop edges instead of black bars
                                        fillMode: VideoOutput.PreserveAspectCrop
                                    }

                                    MediaPlayer {
                                        id: videoPlayer
                                        videoOutput: videoOutput
                                        loops: 1
                                        audioOutput: AudioOutput {
                                            volume: 1.0
                                        }
                                        onErrorOccurred: function(error, errorString) {
                                            videoStatusLabel.text = "Video error: " + errorString
                                            console.log("[VIDEO] error " + errorString)
                                        }
                                        // Freeze on the last frame when the clip finishes
                                        onMediaStatusChanged: {
                                            if (mediaStatus === MediaPlayer.EndOfMedia) {
                                                if (duration > 80)
                                                    position = Math.max(0, duration - 40)
                                                pause()
                                                if (videoTabHelper.currentVideo !== "")
                                                    videoStatusLabel.text = "Ended: " + videoTabHelper.currentVideo + ".mp4 (last frame)"
                                                console.log("[VIDEO] end – holding last frame")
                                            }
                                        }
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        visible: videoTabHelper.currentVideo === ""
                                        text: "No video selected"
                                        color: "#666666"
                                        font.family: "Monospace"
                                        font.pixelSize: 13
                                    }

                                    Text {
                                        id: videoStatusLabel
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        text: "Choose a video"
                                        color: "#b0ac63"
                                        font.family: "Monospace"
                                        font.pixelSize: 10
                                        opacity: 0.9
                                    }
                                }
                            }
                        }


                        // ===== Personal tab =====
                        Item {
                            id: personalTabHelper
                            width: columnsFlick.width
                            height: columnsFlick.height

                            property string personalOutput: "Choose a button above to load data from the phone."
                            property string personalBusy: ""

                            function loadEmails() {
                                personalBusy = "emails"
                                personalOutput = "Loading registered email accounts…"
                                personalProc.command = [
                                    "bash", "-c",
                                    "adb shell dumpsys account 2>/dev/null | tr -d '\\r' | "
                                    + "grep -oE '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}' | sort -u"
                                ]
                                personalProc.mode = "emails"
                                personalProc.running = true
                            }

                            function loadContacts() {
                                personalBusy = "contacts"
                                personalOutput = "Loading contacts…"
                                // Robust parse like adb-osint: display_name + data1 only
                                personalProc.command = [
                                    "bash", "-c",
                                    "adb shell content query --uri content://com.android.contacts/data/phones "
                                    + "--projection display_name:data1 2>/dev/null | tr -d '\\r' | "
                                    + "awk '{"
                                    + "name=\"\"; num=\"\"; "
                                    + "if (match($0, /display_name=([^,]*)/, a)) name=a[1]; "
                                    + "if (match($0, /data1=([^,]*)/, b)) num=b[1]; "
                                    + "gsub(/^[ \\t]+|[ \\t]+$/, \"\", name); "
                                    + "gsub(/^[ \\t]+|[ \\t]+$/, \"\", num); "
                                    + "if (name == \"\" || name == \"null\") next; "
                                    + "if (num == \"\" || num == \"null\") next; "
                                    + "print name \"\\t\" num"
                                    + "}'"
                                ]
                                personalProc.mode = "contacts"
                                personalProc.running = true
                            }

                            function loadCalls() {
                                personalBusy = "calls"
                                personalOutput = "Loading call logs…"
                                personalProc.command = [
                                    "bash", "-c",
                                    "adb shell content query --uri content://call_log/calls "
                                    + "--projection name:number:date:type 2>/dev/null | tr -d '\\r' | "
                                    + "awk '{"
                                    + "name=\"\"; num=\"\"; date=\"0\"; "
                                    + "if (match($0, /name=([^,]*)/, a)) name=a[1]; "
                                    + "if (match($0, /number=([^,]*)/, b)) num=b[1]; "
                                    + "if (match($0, /date=([^,]*)/, c)) date=c[1]; "
                                    + "if (num == \"\" || num == \"null\") next; "
                                    + "if (name == \"\" || name == \"null\") name=\"Unknown\"; "
                                    + "cmd = \"date -d @\" int(date/1000) \" \\\"+%Y-%m-%d %H:%M:%S\\\"\"; "
                                    + "cmd | getline d; close(cmd); "
                                    + "if (d == \"\") d=\"?\"; "
                                    + "print d \"\\t\" name \"\\t\" num"
                                    + "}'"
                                ]
                                personalProc.mode = "calls"
                                personalProc.running = true
                            }

                            function loadSms() {
                                personalBusy = "sms"
                                personalOutput = "Loading SMS logs…"
                                personalProc.command = [
                                    "bash", "-c",
                                    "adb shell content query --uri content://sms "
                                    + "--projection address:body:type:date 2>/dev/null | tr -d '\\r' | "
                                    + "awk '{"
                                    + "line=$0; address=\"\"; body=\"\"; type_val=\"1\"; date_val=\"0\"; "
                                    + "if (match(line, /address=([^,]*)/, m)) address=m[1]; "
                                    + "if (match(line, /body=(.*), type=([0-9]+), date=([0-9]+)/, m)) {"
                                    + "  body=m[1]; type_val=m[2]; date_val=m[3]; "
                                    + "} "
                                    + "cmd = \"date -d @\" int(date_val/1000) \" \\\"+%Y-%m-%d %H:%M:%S\\\"\"; "
                                    + "cmd | getline d; close(cmd); "
                                    + "if (d == \"\") d=\"?\"; "
                                    + "type = (type_val == \"1\") ? \"INBOX\" : \"SENT\"; "
                                    + "gsub(/\\t/, \" \", body); "
                                    + "if (length(body) > 80) body = substr(body, 1, 77) \"...\"; "
                                    + "print d \"\\t\" type \"\\t\" address \"\\t\" body"
                                    + "}'"
                                ]
                                personalProc.mode = "sms"
                                personalProc.running = true
                            }

                            function padRight(s, n) {
                                s = String(s || "")
                                if (s.length > n)
                                    return s.substring(0, n)
                                while (s.length < n)
                                    s += " "
                                return s
                            }

                            function nl() { return String.fromCharCode(10) }

                            function formatEmails(raw) {
                                let lines = String(raw).split(String.fromCharCode(10))
                                let emails = []
                                let seen = {}
                                for (let i = 0; i < lines.length; i++) {
                                    let e = lines[i].replace(/\r/g, "").trim()
                                    if (e.indexOf("@") < 0) continue
                                    if (seen[e]) continue
                                    seen[e] = true
                                    emails.push(e)
                                }
                                emails.sort()
                                if (emails.length === 0)
                                    return "Registered emails (0)" + nl() + "No email accounts found."
                                let out = "Registered emails (" + emails.length + ")" + nl() + nl()
                                for (let j = 0; j < emails.length; j++)
                                    out += "  " + emails[j] + nl()
                                return out
                            }

                            function formatContacts(raw) {
                                let lines = String(raw).split(String.fromCharCode(10))
                                let map = {}
                                let order = []
                                let maxName = 8
                                for (let i = 0; i < lines.length; i++) {
                                    let line = lines[i].replace(/\r/g, "").trim()
                                    if (!line.length) continue
                                    // Prefer tab; also accept multiple spaces
                                    let name = ""
                                    let num = ""
                                    let tab = line.indexOf(String.fromCharCode(9))
                                    if (tab >= 0) {
                                        name = line.substring(0, tab).trim()
                                        num = line.substring(tab + 1).trim()
                                    } else {
                                        // last token looks like phone?
                                        let m = line.match(/^(.*?)[\s]+([+\d][\d\s\-()]{5,})$/)
                                        if (!m) continue
                                        name = m[1].trim()
                                        num = m[2].trim()
                                    }
                                    if (!name || name === "null") continue
                                    if (!num || num === "null") continue
                                    if (!map[name]) {
                                        map[name] = []
                                        order.push(name)
                                    }
                                    if (name.length > maxName) maxName = name.length
                                    if (map[name].indexOf(num) < 0)
                                        map[name].push(num)
                                }
                                if (maxName > 28) maxName = 28
                                if (order.length === 0)
                                    return "Contacts (0)" + nl() + "No contacts found or access denied."
                                order.sort(function(a, b) { return a.toLowerCase().localeCompare(b.toLowerCase()) })
                                let out = "Contacts (" + order.length + ")" + nl() + nl()
                                out += padRight("Name", maxName) + "  Number" + nl()
                                for (let j = 0; j < order.length; j++) {
                                    let n = order[j]
                                    let nums = map[n]
                                    let dn = n.length > maxName ? n.substring(0, maxName - 1) + "…" : n
                                    out += padRight(dn, maxName) + "  " + nums[0] + nl()
                                    for (let p = 1; p < nums.length; p++)
                                        out += padRight("", maxName) + "  " + nums[p] + nl()
                                }
                                return out
                            }

                            function formatCalls(raw) {
                                let lines = String(raw).split(String.fromCharCode(10))
                                let rows = []
                                for (let i = 0; i < lines.length; i++) {
                                    let line = lines[i].replace(/\r/g, "").trim()
                                    if (!line.length) continue
                                    let parts = line.split(String.fromCharCode(9))
                                    if (parts.length < 3) continue
                                    rows.push(parts)
                                }
                                if (rows.length === 0)
                                    return "Call logs (0)" + nl() + "No call logs found or access denied."
                                let out = "Call logs (" + rows.length + ")" + nl() + nl()
                                out += padRight("Date / Time", 19) + "  " + padRight("Name", 18) + "  Number" + nl()
                                let max = Math.min(rows.length, 400)
                                for (let i = 0; i < max; i++) {
                                    let d = rows[i][0] || ""
                                    let name = rows[i][1] || "Unknown"
                                    let num = rows[i][2] || ""
                                    if (name.length > 18) name = name.substring(0, 17) + "…"
                                    out += padRight(d, 19) + "  " + padRight(name, 18) + "  " + num + nl()
                                }
                                if (rows.length > max)
                                    out += nl() + "… and " + (rows.length - max) + " more" + nl()
                                return out
                            }

                            function formatSms(raw) {
                                let lines = String(raw).split(String.fromCharCode(10))
                                let rows = []
                                for (let i = 0; i < lines.length; i++) {
                                    let line = lines[i].replace(/\r/g, "").trim()
                                    if (!line.length) continue
                                    let parts = line.split(String.fromCharCode(9))
                                    if (parts.length < 3) continue
                                    rows.push(parts)
                                }
                                if (rows.length === 0)
                                    return "SMS logs (0)" + nl() + "No SMS found or access denied." + nl()
                                        + "(Grant: adb shell pm grant com.android.shell android.permission.READ_SMS)"
                                let out = "SMS logs (" + rows.length + ")" + nl() + nl()
                                out += padRight("Date / Time", 19) + "  " + padRight("Type", 6) + "  " + padRight("Number", 14) + "  Message" + nl()
                                let max = Math.min(rows.length, 400)
                                for (let i = 0; i < max; i++) {
                                    let d = rows[i][0] || ""
                                    let tl = rows[i][1] || "?"
                                    let addr = rows[i][2] || ""
                                    let msg = rows[i].slice(3).join(" ") || ""
                                    out += padRight(d, 19) + "  " + padRight(tl, 6) + "  " + padRight(addr, 14) + "  " + msg + nl()
                                }
                                if (rows.length > max)
                                    out += nl() + "… and " + (rows.length - max) + " more" + nl()
                                return out
                            }

                            Process {
                                id: personalProc
                                property string mode: ""
                                command: []
                                stdout: StdioCollector {
                                    onStreamFinished: {
                                        let raw = text
                                        let mode = personalProc.mode
                                        console.log("[PERSONAL] mode=" + mode + " rawLen=" + raw.length + " head=" + raw.substring(0, 120).replace(/\n/g, " | "))
                                        if (mode === "emails")
                                            personalTabHelper.personalOutput = personalTabHelper.formatEmails(raw)
                                        else if (mode === "contacts")
                                            personalTabHelper.personalOutput = personalTabHelper.formatContacts(raw)
                                        else if (mode === "calls")
                                            personalTabHelper.personalOutput = personalTabHelper.formatCalls(raw)
                                        else if (mode === "sms")
                                            personalTabHelper.personalOutput = personalTabHelper.formatSms(raw)
                                        else
                                            personalTabHelper.personalOutput = raw.substring(0, 5000)
                                        personalTabHelper.personalBusy = ""
                                    }
                                }
                                stderr: StdioCollector {
                                    onStreamFinished: {
                                        if (text.trim().length > 0)
                                            console.log("[PERSONAL] stderr: " + text.trim().substring(0, 300))
                                    }
                                }
                                onExited: function(code) {
                                    if (code !== 0 && personalTabHelper.personalBusy !== "") {
                                        personalTabHelper.personalOutput += "\\n\\n(Command exited with code " + code + ")"
                                        personalTabHelper.personalBusy = ""
                                    }
                                }
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 10

                                Text {
                                    text: "Personal"
                                    color: "#dde5a2"
                                    font.bold: true
                                    font.family: "Monospace"
                                    font.pixelSize: 14
                                    Layout.fillWidth: true
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { label: "Emails", action: "emails" },
                                            { label: "Contacts", action: "contacts" },
                                            { label: "Call logs", action: "calls" },
                                            { label: "Sms logs", action: "sms" }
                                        ]
                                        Button {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 36
                                            text: modelData.label
                                            font.pixelSize: 12
                                            font.family: "Monospace"
                                            font.bold: personalTabHelper.personalBusy === modelData.action
                                            enabled: personalTabHelper.personalBusy === ""
                                            scale: pressed ? 0.96 : 1.0
                                            Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
                                            background: Rectangle {
                                                radius: 8
                                                color: personalTabHelper.personalBusy === modelData.action
                                                       ? "#4a5538" : (parent.pressed ? Qt.darker("#363c30", 1.1) : "#363c30")
                                                border.color: personalTabHelper.personalBusy === modelData.action
                                                              ? "#b0ac63" : Qt.darker("#555839", 1.2)
                                                border.width: 1
                                            }
                                            contentItem: Text {
                                                text: parent.text
                                                font: parent.font
                                                color: parent.enabled ? "#dde5a2" : "#666"
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                            onClicked: {
                                                if (modelData.action === "emails") personalTabHelper.loadEmails()
                                                else if (modelData.action === "contacts") personalTabHelper.loadContacts()
                                                else if (modelData.action === "calls") personalTabHelper.loadCalls()
                                                else if (modelData.action === "sms") personalTabHelper.loadSms()
                                            }
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

                                    ScrollView {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        clip: true

                                        TextArea {
                                            readOnly: true
                                            textFormat: TextEdit.PlainText
                                            text: personalTabHelper.personalOutput
                                            color: "#dde5a2"
                                            font.family: "Monospace"
                                            font.pixelSize: 12
                                            background: null
                                            wrapMode: TextEdit.NoWrap
                                        }
                                    }
                                }
                            }
                        }

                    }   // end columnsRow
                }       // end columnsFlick
                }       // end appViewsContainer


                // Selected App Information Box Output (Visible on Google, Third-Party, and Search tabs)
                // Description is fetched live from Gemini on left-click; safe-to-remove uses local heuristics
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: selectedAppInfo !== null ? 155 : 0
                    visible: selectedAppInfo !== null && (currentColumn === 0 || currentColumn === 1 || currentColumn === 2 || currentColumn === 6 || currentColumn === 9 || currentColumn === 10)
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

                        // Safety verdict – label depends on which tab triggered the query
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Text {
                                text: {
                                    if (!selectedAppInfo) return "Safe to Remove:";
                                    let m = selectedAppInfo.queryMode || "debloat";
                                    if (m === "battery") return "Safe to Restrict:";
                                    if (m === "cammic") return "Safe to Revoke:";
                                    if (m === "connection") return "Risk Level:";
                                    return "Safe to Remove:";
                                }
                                color: "#b0ac63"
                                font.pixelSize: 12
                                font.family: "Monospace"
                                font.bold: true
                            }

                            Text {
                                text: selectedAppInfo ? selectedAppInfo.safeToRemove : ""
                                color: selectedAppInfo ? (
                                    selectedAppInfo.safeToRemove === "Yes" || selectedAppInfo.safeToRemove === "Low" ? "#88ff88" :
                                    selectedAppInfo.safeToRemove === "No" || selectedAppInfo.safeToRemove === "High" ? "#ff7777" :
                                    "#ffff77"
                                ) : "#dde5a2"
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

                // Bottom action buttons – single horizontal row
                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    spacing: 8

                    Button {
                        id: nukeBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        visible: currentColumn === 7
                        text: secureTabHelper.isNuking ? "Nuking…" : "Nuke Phone"
                        font.pixelSize: 13
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
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        text: isPhoneVisible ? "Close phone" : "Show phone"
                        font.pixelSize: 13
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
                                scrcpyReconnectTimer.stop()
                                isPhoneVisible = false
                                killScrcpyProc.running = true
                            } else {
                                isPhoneVisible = true
                                killScrcpyProc.running = false
                                startScrcpyProc.running = true
                            }
                        }
                    }

                    Button {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        visible: currentColumn === 0 || currentColumn === 1
                        text: "Re-check"
                        font.pixelSize: 13
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

                    Button {
                        id: applyBtn
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        visible: currentColumn === 0 || currentColumn === 1 || currentColumn === 2
                        text: "Apply (" + (appsToUninstall.length + appsToEnable.length) + ")"
                        font.pixelSize: 13
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
            // List ALL packages (not only -3) so pre-installed system bloat like Facebook,
            // Instagram, etc. still appear. Filter out true system-critical + Google/Samsung
            // framework packages the same way the Search tab's "third party" mode does.
            command: ["bash", "-c", "adb shell pm list packages | sed 's/package://'"]

            stdout: StdioCollector {
                onStreamFinished: {
                    thirdPartyAppsModel.clear();
                    let lines = text.trim().split("\n");
                    let items = [];
                    for (let i = 0; i < lines.length; i++) {
                        let pkg = lines[i].trim();
                        if (pkg.length === 0) continue;

                        // Same filter used by Search tab "third party" mode so Facebook etc. show up
                        // even when the OEM installed them as system packages.
                        let isUserLike = !isSystemCritical(pkg) &&
                        !pkg.startsWith("com.google.") &&
                        !pkg.startsWith("com.android.") &&
                        !pkg.startsWith("android.") &&
                        !pkg.startsWith("com.samsung.") &&
                        !pkg.startsWith("com.sec.");

                        if (isUserLike) {
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
                "echo SDK=$(adb shell getprop ro.build.version.sdk 2>/dev/null | tr -d '\\r'); " +
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
                        } else if (line.startsWith("SDK=")) {
                            let sdk = parseInt(line.substring(4).trim());
                            phoneSdkInt = isNaN(sdk) ? 0 : sdk;
                        } else if (line.startsWith("FIRSTAPI=")) {
                            let api = parseInt(line.substring(9).trim());
                            let yearMap = {
                                21: 2014, 22: 2015, 23: 2015, 24: 2016, 25: 2016,
                                26: 2017, 27: 2018, 28: 2018, 29: 2019, 30: 2020,
                                31: 2021, 32: 2022, 33: 2022, 34: 2023, 35: 2024,
                                36: 2025
                            };
                            phoneReleaseYear = yearMap[api] ? String(yearMap[api]) : (isNaN(api) ? "-" : "API " + api);
                        }
                    }
                    phoneBrandFamily = detectBrandFamily(phoneManufacturer, phoneModel);
                    console.log("[DEVICE] brand=" + phoneBrandFamily + " model=" + phoneModel +
                                " android=" + phoneAndroid + " sdk=" + phoneSdkInt);
                }
            }
        }

        Process {
            id: fetchThumbnailsProc
            command: [
                "bash", "-c",
                "set +e; COUNT=0; SIZE_KB=0; "
                + "scan_one() { local d=\"$1\"; local c s; "
                + "c=$(adb shell ls -1 \"$d\" 2>/dev/null | wc -l | tr -d ' '); "
                + "s=$(adb shell du -sk \"$d\" 2>/dev/null | awk '{print $1}'); "
                + "c=${c:-0}; s=${s:-0}; "
                + "if [ \"$c\" -gt 0 ] 2>/dev/null; then COUNT=$((COUNT+c)); SIZE_KB=$((SIZE_KB+s)); "
                + "echo \"[THUMBS DIR] $d files=$c kb=$s\" >&2; fi; }; "
                + "scan_one /sdcard/Pictures/.thumbnails; "
                + "scan_one /sdcard/DCIM/.thumbnails; "
                + "scan_one /sdcard/Movies/.thumbnails; "
                + "scan_one /sdcard/Download/.thumbnails; "
                + "scan_one /storage/emulated/0/Pictures/.thumbnails; "
                + "scan_one /storage/emulated/0/DCIM/.thumbnails; "
                + "scan_one /sdcard/Android/data/com.sec.android.gallery3d/cache; "
                + "scan_one /sdcard/Android/data/com.samsung.android.gallery3d/cache; "
                + "scan_one /sdcard/Android/data/com.miui.gallery/cache; "
                + "scan_one /sdcard/Android/data/com.google.android.apps.photos/cache; "
                + "TMP=$(mktemp); "
                + "adb shell find /sdcard /storage/emulated/0 -type d -name .thumbnails 2>/dev/null | tr -d '\\r' > \"$TMP\"; "
                + "while IFS= read -r d; do [ -z \"$d\" ] && continue; scan_one \"$d\"; done < \"$TMP\"; "
                + "rm -f \"$TMP\"; "
                + "echo COUNT=$COUNT; echo SIZE_KB=$SIZE_KB"
            ]
            stdout: StdioCollector {
                onStreamFinished: {
                    console.log("[THUMBS RAW] " + text.trim().substring(0, 400));
                    let count = 0;
                    let sizeKb = 0;
                    let lines = text.trim().split("\n");
                    for (let i = 0; i < lines.length; i++) {
                        let line = lines[i].trim();
                        if (line.startsWith("COUNT="))
                            count = parseInt(line.substring(6).trim()) || 0;
                        else if (line.startsWith("SIZE_KB="))
                            sizeKb = parseInt(line.substring(8).trim()) || 0;
                    }
                    thumbnailCount = count;
                    thumbnailSizeLabel = formatBytes(sizeKb * 1024);
                    console.log("[THUMBS] count=" + thumbnailCount + " size=" + thumbnailSizeLabel);
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length)
                        console.log("[THUMBS] stderr: " + text.trim().substring(0, 200));
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
            id: playStoreLaunchProc
            command: []
        }

        Process {
            id: playStoreConnectCheckProc
            command: ["adb", "shell", "pm", "list", "packages", "com.android.vending"]
            stdout: StdioCollector {
                onStreamFinished: {
                    let pkg = pendingPlayStorePkg
                    console.log("[PLAY] vending check result length=" + text.trim().length + " pending=" + pkg)
                    if (pkg !== "") {
                        // Open Play Store details even if package list parse is flaky
                        let marketUrl = "market://details?id=" + pkg
                        let httpsUrl = "https://play.google.com/store/apps/details?id=" + pkg
                        if (text.trim().indexOf("com.android.vending") >= 0) {
                            playStoreLaunchProc.command = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", marketUrl]
                        } else {
                            // Fallback: browser / any handler for Play Store HTTPS link
                            playStoreLaunchProc.command = ["adb", "shell", "am", "start", "-a", "android.intent.action.VIEW", "-d", httpsUrl]
                        }
                        playStoreLaunchProc.running = true
                        console.log("[PLAY] launching " + playStoreLaunchProc.command.join(" "))
                    }
                    pendingPlayStorePkg = ""
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length)
                        console.log("[PLAY] stderr: " + text.trim())
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
                            // Prefer free-tier friendly text flash models; exclude specialised
                            // (tts / image / vision / embedding / code / aqa) and experimental variants.
                            let score = 0;
                            let lower = name.toLowerCase();
                            // Hard exclude models unsuitable for plain text generation
                            if (lower.includes("tts") || lower.includes("image") ||
                                lower.includes("vision") || lower.includes("embedding") ||
                                lower.includes("aqa") || lower.includes("code-") ||
                                lower.includes("imagen") || lower.includes("veo")) {
                                continue;
                            }
                            if (lower.includes("flash")) score += 50;
                            if (lower.includes("lite")) score += 10;
                            if (lower.includes("2.5") || lower.includes("2.0") || lower.includes("1.5")) score += 20;
                            if (lower.includes("3.")) score += 25;          // newer generations
                            if (lower.includes("pro")) score -= 30;
                            if (lower.includes("ultra")) score -= 40;
                            if (lower.includes("thinking") || lower.includes("exp") || lower.includes("preview")) score -= 15;
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
            property string queryMode: "debloat"       // debloat | battery | cammic | connection
            property string queryContext: ""
            command: []

            // Public entry point – discovers model on first call
            // mode: "debloat" (default), "battery", "cammic", "connection"
            // context: optional display name or extra info for the prompt
            function queryPkg(pkg, mode, context) {
                currentPkg = pkg;
                queryMode = mode || "debloat";
                queryContext = context || "";

                // Wait until the key has been loaded from disk
                if (!geminiKeyLoaded) {
                    // Key loader is still running – re-try shortly (preserve mode/context)
                    Qt.callLater(function() { geminiDescProc.queryPkg(pkg, mode, context); });
                    return;
                }

                if (geminiApiKey.length === 0) {
                    if (selectedAppInfo && selectedAppInfo.pkg === pkg) {
                        selectedAppInfo = {
                            pkg: pkg,
                            description: "No Gemini API key found.\n\nCreate the file:\n  ~/.config/debloat-phone/gemini.key\n(or place gemini.key next to this QML file)\nand put your free API key inside it (one line only).\n\nGet a key at: https://aistudio.google.com/apikey",
                            safeToRemove: "—",
                            category: selectedAppInfo.category,
                            queryMode: queryMode
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
                            category: selectedAppInfo.category,
                            queryMode: queryMode
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

                // Mode-specific prompts for debloat / battery / cammic / connection
                let mode = geminiDescProc.queryMode || "debloat";
                let ctx = geminiDescProc.queryContext || "";
                let prompt = "";
                if (mode === "battery") {
                    prompt =
                    "Android package: \"" + pkg + "\"\n" +
                    (ctx ? ("Display name: " + ctx + "\n") : "") +
                    "Question: What does this app/service do, and is it safe to put it in Android battery restricted / deep-sleep mode (standby bucket restricted)?\n" +
                    "1. First line exactly: Safe to restrict: Yes   OR   Safe to restrict: No   OR   Safe to restrict: Caution\n" +
                    "2. Second line: short reason (max 15 words).\n" +
                    "3. Blank line, then description of what it does and impact of restricting battery (max 90 words).\n" +
                    "Be practical for a regular user. Do not mention this prompt.";
                } else if (mode === "cammic") {
                    prompt =
                    "Android package: \"" + pkg + "\"\n" +
                    (ctx ? ("Extra: " + ctx + "\n") : "") +
                    "This app currently has camera and/or microphone and/or location permission.\n" +
                    "1. First line exactly: Safe to revoke: Yes   OR   Safe to revoke: No   OR   Safe to revoke: Caution\n" +
                    "2. Second line: short reason (max 15 words).\n" +
                    "3. Blank line, then what the app does and whether denying camera, mic, and location is safe or will break features (max 90 words).\n" +
                    "Be practical. Do not mention this prompt.";
                } else if (mode === "connection") {
                    prompt =
                    "An Android phone has an active network connection:\n" +
                    ctx + "\n" +
                    "1. First line exactly: Risk level: Low   OR   Risk level: Medium   OR   Risk level: High\n" +
                    "2. Second line: short reason (max 15 words).\n" +
                    "3. Blank line, then what this connection likely is (company/service), why the phone might contact it, and whether it looks normal or suspicious (max 100 words).\n" +
                    "Be practical. Do not mention this prompt.";
                } else {
                    prompt =
                    "For the Android package \"" + pkg + "\":\n" +
                    "1. First line exactly in this format: Safe to remove: Yes   OR   Safe to remove: No   OR   Safe to remove: Caution\n" +
                    "2. Second line: a short reason (max 15 words).\n" +
                    "3. Then a blank line followed by a concise description of what the package does (max 80 words).\n" +
                    "Focus on a regular user's perspective. Do not mention this prompt.";
                }
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

                        if (lowerFirst.startsWith("safe to remove:") ||
                            lowerFirst.startsWith("safe to restrict:") ||
                            lowerFirst.startsWith("safe to revoke:") ||
                            lowerFirst.startsWith("risk level:")) {
                            let colon = firstLine.indexOf(":");
                            let verdict = colon >= 0 ? firstLine.substring(colon + 1).trim() : firstLine;
                            let vLower = verdict.toLowerCase();
                            if (vLower.startsWith("yes") || vLower.startsWith("low")) safeStatus = lowerFirst.startsWith("risk") ? "Low" : "Yes";
                            else if (vLower.startsWith("no") || vLower.startsWith("high")) safeStatus = lowerFirst.startsWith("risk") ? "High" : "No";
                            else if (vLower.startsWith("caution") || vLower.startsWith("maybe") || vLower.startsWith("medium")) safeStatus = lowerFirst.startsWith("risk") ? "Medium" : "Caution";
                            else safeStatus = verdict;

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
                                if (geminiDescProc.isHighDemandError(errorMsg)) {
                                    shouldRetry = true;
                                }
                            }
                    } catch (e) {
                        // Sometimes the API returns a plain-text error instead of JSON
                        let rawText = text.trim();
                        if (geminiDescProc.isHighDemandError(rawText)) {
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
                        if (geminiDescProc.tryNextModel(geminiDescProc.currentPkg)) {
                            return;   // retry started – do not update UI with the error yet
                        }
                    }

                    // Only update if the user has not clicked a different package in the meantime
                    if (selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        selectedAppInfo = {
                            pkg: geminiDescProc.currentPkg,
                            description: desc,
                            safeToRemove: safeStatus,
                            category: selectedAppInfo.category,
                            queryMode: geminiDescProc.queryMode
                        };
                    }
                }
            }
            stderr: StdioCollector {
                onStreamFinished: {
                    if (text.trim().length === 0) return;
                    let err = text.trim();
                    if (geminiDescProc.isHighDemandError(err) && selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        if (geminiDescProc.tryNextModel(geminiDescProc.currentPkg)) {
                            return;
                        }
                    }
                    if (selectedAppInfo && selectedAppInfo.pkg === geminiDescProc.currentPkg) {
                        selectedAppInfo = {
                            pkg: geminiDescProc.currentPkg,
                            description: "Gemini query error: " + err.substring(0, 150),
                            safeToRemove: selectedAppInfo.safeToRemove,
                            category: selectedAppInfo.category,
                            queryMode: geminiDescProc.queryMode
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
