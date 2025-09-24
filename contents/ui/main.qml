import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Enhanced data properties
    property int batteryLevel: -1
    property bool isCharging: false
    property bool isConnected: false
    property real currentAmps: 0.0          // Current in amperes
    property real voltageVolts: 0.0         // Voltage in volts
    property real powerWatts: 0.0           // Power in watts
    property real chargeNowAh: 0.0          // Current charge in Ah
    property real chargeFullAh: 0.0         // Full charge in Ah
    property string timeRemaining: ""       // Formatted remaining time
    property string batteryPath: "/sys/class/power_supply/BAT0"
    property string detailedInfo: ""        // Detailed information

    // Plasmoid configuration with dynamic information
    Plasmoid.title: batteryLevel >= 0 ?
        "Battery " + batteryLevel + "% • " + timeRemaining :
        "Battery Unknown"

    // Configuration du tooltip classique - activé par défaut
    toolTipMainText: batteryLevel >= 0 ? "Battery " + batteryLevel + "%" : "Battery Unknown"
    toolTipSubText: detailedInfo

    // DataSource for executing system commands
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) {
            disconnectSource(source)
        }

        function exec(cmd) {
            executable.connectSource(cmd)
        }
    }

    // Timer for data updates
    Timer {
        id: updateTimer
        interval: 2000 // 2 seconds for detailed information
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateAdvancedBatteryInfo()
    }

    // Function to read a system file
    function readSystemFile(path) {
        var request = new XMLHttpRequest()
        request.open('GET', 'file://' + path, false)
        try {
            request.send()
            if (request.status === 200) {
                return request.responseText.trim()
            }
        } catch (e) {
            // File not accessible
        }
        return ""
    }

    // Function to find the correct battery path
    function findBatteryPath() {
        var testPaths = [
            "/sys/class/power_supply/BAT0",
            "/sys/class/power_supply/BAT1",
            "/sys/class/power_supply/BATT"
        ]

        for (var i = 0; i < testPaths.length; i++) {
            var capacity = readSystemFile(testPaths[i] + "/capacity")
            if (capacity !== "") {
                batteryPath = testPaths[i]
                return true
            }
        }
        return false
    }

    // Main advanced update function
    function updateAdvancedBatteryInfo() {
        // Find the correct battery path if necessary
        if (batteryLevel === -1) {
            if (!findBatteryPath()) {
                detailedInfo = "No battery found"
                return
            }
        }

        // Read battery level
        var capacityStr = readSystemFile(batteryPath + "/capacity")
        if (capacityStr !== "") {
            batteryLevel = parseInt(capacityStr)
        } else {
            batteryLevel = -1
            detailedInfo = "Battery information unavailable"
            return
        }

        // Read charging status
        var status = readSystemFile(batteryPath + "/status")
        isCharging = (status === "Charging")
        isConnected = (status === "Charging" || status === "Full")

        // Read current (in microamperes)
        var currentNowStr = readSystemFile(batteryPath + "/current_now")
        if (currentNowStr !== "") {
            currentAmps = parseInt(currentNowStr) / 1000000.0 // µA → A
        } else {
            currentAmps = 0.0
        }

        // Read voltage (in microvolts)
        var voltageNowStr = readSystemFile(batteryPath + "/voltage_now")
        if (voltageNowStr !== "") {
            voltageVolts = parseInt(voltageNowStr) / 1000000.0 // µV → V
        } else {
            voltageVolts = 0.0
        }

        // Calculate power
        var powerNowStr = readSystemFile(batteryPath + "/power_now")
        if (powerNowStr !== "") {
            // Power directly available (in µW)
            powerWatts = parseInt(powerNowStr) / 1000000.0
        } else if (currentAmps !== 0 && voltageVolts !== 0) {
            // Calculate power P = V × I
            powerWatts = Math.abs(voltageVolts * currentAmps)
        } else {
            powerWatts = 0.0
        }

        // Read capacities for time calculation
        var chargeNowStr = readSystemFile(batteryPath + "/charge_now")
        var chargeFullStr = readSystemFile(batteryPath + "/charge_full")
        if (chargeNowStr !== "" && chargeFullStr !== "") {
            chargeNowAh = parseInt(chargeNowStr) / 1000000.0  // µAh → Ah
            chargeFullAh = parseInt(chargeFullStr) / 1000000.0 // µAh → Ah

            // Calculate remaining time
            calculateTimeRemaining()
        } else {
            timeRemaining = "Unknown time"
        }

        // Build detailed information
        buildDetailedInfo()

        // Dynamic update of plasmoid title and tooltip
        Plasmoid.title = batteryLevel >= 0 ?
            "Battery " + batteryLevel + "% • " + timeRemaining :
            "Battery Unknown"

        // Mise à jour du tooltip
        toolTipMainText = batteryLevel >= 0 ? "Battery " + batteryLevel + "%" : "Battery Unknown"
        toolTipSubText = detailedInfo
    }

    // Calculate remaining time according to Linux formulas
    function calculateTimeRemaining() {
        if (currentAmps === 0) {
            timeRemaining = "Cannot calculate"
            return
        }

        var timeHours = 0.0

        if (isCharging) {
            // Time to reach full charge
            // Formula: (CHARGE_FULL - CHARGE_NOW) / CURRENT_NOW
            timeHours = (chargeFullAh - chargeNowAh) / Math.abs(currentAmps)
        } else {
            // Discharge time
            // Formula: CHARGE_NOW / CURRENT_NOW
            timeHours = chargeNowAh / Math.abs(currentAmps)
        }

        // Time formatting
        if (timeHours < 0.01) {
            timeRemaining = "< 1 min"
        } else if (timeHours >= 24) {
            timeRemaining = Math.floor(timeHours / 24) + "d " + Math.floor(timeHours % 24) + "h"
        } else if (timeHours >= 1) {
            var hours = Math.floor(timeHours)
            var minutes = Math.floor((timeHours - hours) * 60)
            timeRemaining = hours + "h " + minutes + "min"
        } else {
            var minutes = Math.floor(timeHours * 60)
            timeRemaining = minutes + " min"
        }
    }

    // Build detailed information for tooltip
    function buildDetailedInfo() {
        var parts = []

        // Basic status
        var statusText = ""
        if (isCharging) {
            statusText = "Charging"
        } else if (batteryLevel === 100) {
            statusText = "Charged"
        } else {
            statusText = "On battery"
        }
        parts.push(statusText)

        // Charge/discharge current
        if (currentAmps !== 0) {
            var currentText = isCharging ?
                "Charge: +" + Math.abs(currentAmps).toFixed(2) + " A" :
                "Discharge: -" + Math.abs(currentAmps).toFixed(2) + " A"
            parts.push(currentText)
        }

        // Power
        if (powerWatts > 0.1) {
            parts.push("Power: " + powerWatts.toFixed(1) + " W")
        }

        // Voltage
        if (voltageVolts > 0) {
            parts.push("Voltage: " + voltageVolts.toFixed(1) + " V")
        }

        // Estimated time
        if (timeRemaining !== "") {
            var timeText = isCharging ?
                "Full charge in: " + timeRemaining :
                "Remaining time: " + timeRemaining
            parts.push(timeText)
        }

        detailedInfo = parts.join("\n")  // Utiliser des retours à la ligne pour le tooltip
    }

    function getBatteryIconName() {
        if (batteryLevel < 0) return "battery-missing"

        var iconBase = "battery-"
        // Add level suffix
        if (batteryLevel <= 10) iconBase += "010"
        else if (batteryLevel <= 20) iconBase += "020"
        else if (batteryLevel <= 30) iconBase += "030"
        else if (batteryLevel <= 40) iconBase += "040"
        else if (batteryLevel <= 50) iconBase += "050"
        else if (batteryLevel <= 60) iconBase += "060"
        else if (batteryLevel <= 70) iconBase += "070"
        else if (batteryLevel <= 80) iconBase += "080"
        else if (batteryLevel <= 90) iconBase += "090"
        else iconBase += "100"

        // Add charging suffix
        if (isCharging) iconBase += "-charging"

        return iconBase
    }

    function getTextColor() {
        if (batteryLevel < 0) return Kirigami.Theme.disabledTextColor
        if (batteryLevel <= 15 && !isCharging) return Kirigami.Theme.negativeTextColor
        if (batteryLevel <= 25 && !isCharging) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }

    // Fenêtre popup personnalisée - ouverte uniquement au clic
    PlasmaCore.Dialog {
        id: detailsPopup

        // Propriétés de la fenêtre
        type: PlasmaCore.Dialog.PopupMenu
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true

        // Contenu ajouté comme enfant direct
        ColumnLayout {
            id: popupContent
            width: Kirigami.Units.gridUnit * 18
            height: Kirigami.Units.gridUnit * 14
            spacing: Kirigami.Units.largeSpacing

            // Header avec icône et niveau
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: getBatteryIconName()
                    width: Kirigami.Units.iconSizes.large
                    height: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    PlasmaComponents3.Label {
                        text: batteryLevel >= 0 ? batteryLevel + "%" : "Unknown"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                        font.bold: true
                        color: getTextColor()
                    }
                    PlasmaComponents3.Label {
                        text: isCharging ? "🔌 Charging" :
                            (batteryLevel === 100 ? "✓ Fully charged" : "🔋 On battery")
                        opacity: 0.9
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }
                }
            }

            // Barre de progression avec couleur dynamique
            PlasmaComponents3.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Math.max(0, batteryLevel)

                // Couleur de la barre selon le niveau
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Kirigami.Theme.disabledTextColor
                    opacity: 0.3
                    radius: 3
                }
            }

            // Informations détaillées en grille plus espacée
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing * 1.5
                rowSpacing: Kirigami.Units.largeSpacing

                // Current
                PlasmaComponents3.Label {
                    text: "⚡ Current:"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                PlasmaComponents3.Label {
                    text: currentAmps !== 0 ?
                        (isCharging ? "+" : "-") + Math.abs(currentAmps).toFixed(2) + " A" :
                        "Unknown"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    color: currentAmps !== 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }

                // Power
                PlasmaComponents3.Label {
                    text: "💡 Power:"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                PlasmaComponents3.Label {
                    text: powerWatts > 0.1 ? powerWatts.toFixed(1) + " W" : "Unknown"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    color: powerWatts > 0.1 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }

                // Voltage
                PlasmaComponents3.Label {
                    text: "🔌 Voltage:"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                PlasmaComponents3.Label {
                    text: voltageVolts > 0 ? voltageVolts.toFixed(1) + " V" : "Unknown"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    color: voltageVolts > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }

                // Remaining time
                PlasmaComponents3.Label {
                    text: isCharging ? "⏱️ Full charge:" : "⏰ Battery life:"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                PlasmaComponents3.Label {
                    text: timeRemaining || "Cannot calculate"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    color: timeRemaining && timeRemaining.includes("min") ? 
                           (batteryLevel <= 15 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.neutralTextColor) :
                           Kirigami.Theme.textColor
                    font.bold: batteryLevel <= 15 && !isCharging
                }

                // Capacities
                PlasmaComponents3.Label {
                    text: "🔋 Capacity:"
                    font.bold: true
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                }
                PlasmaComponents3.Label {
                    text: chargeNowAh > 0 && chargeFullAh > 0 ?
                        chargeNowAh.toFixed(1) + " / " + chargeFullAh.toFixed(1) + " Ah (" + 
                        Math.round((chargeNowAh / chargeFullAh) * 100) + "%)" :
                        "Unknown"
                    font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    color: chargeNowAh > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
                }
            }

            Item { Layout.fillHeight: true }

            // Ligne de boutons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                // Bouton pour fermer
                PlasmaComponents3.Button {
                    text: "Close"
                    icon.name: "window-close"
                    onClicked: {
                        detailsPopup.visible = false
                    }
                }

                // Bouton pour ouvrir les paramètres
                PlasmaComponents3.Button {
                    text: "Power Settings..."
                    icon.name: "preferences-system-power-management"
                    onClicked: {
                        executable.exec("kcmshell6 kcm_powerdevilprofilesconfig")
                        detailsPopup.visible = false
                    }
                }
            }
        }

        // Fonction pour afficher la popup (clic uniquement)
        function showPopup() {
            visible = true
        }
    }

    // Compact representation simplifiée - UNE SEULE LIGNE
    compactRepresentation: Item {
        id: compactItem
        Layout.preferredWidth: batteryRow.implicitWidth
        Layout.preferredHeight: batteryRow.implicitHeight
        Layout.minimumWidth: batteryRow.implicitWidth
        Layout.minimumHeight: Layout.preferredHeight

        // Une seule ligne : icône + pourcentage
        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            // Battery icon
            Kirigami.Icon {
                id: batteryIcon
                source: getBatteryIconName()
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                color: getTextColor()

                // Pulsation animation while charging
                SequentialAnimation on opacity {
                    running: isCharging && batteryLevel < 100
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.6
                        duration: 1000
                        easing.type: Easing.InOutQuad
                    }
                    NumberAnimation {
                        to: 1.0
                        duration: 1000
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            // Percentage text uniquement
            PlasmaComponents3.Label {
                id: batteryText
                text: batteryLevel >= 0 ? batteryLevel + "%" : "?"
                color: getTextColor()
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: batteryLevel <= 15 && !isCharging
            }
        }

        // MouseArea pour le clic uniquement - pas de gestion du survol
        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: false  // Désactivé pour laisser le tooltip standard

            onClicked: {
                // Toggle de la popup au clic
                if (detailsPopup.visible) {
                    detailsPopup.visible = false
                } else {
                    detailsPopup.showPopup()
                }
            }
        }
    }

    // Full representation pour compatibilité (utilisée quand le widget est étendu)
    fullRepresentation: PlasmaComponents3.Page {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Header with icon and level
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    source: getBatteryIconName()
                    width: Kirigami.Units.iconSizes.large
                    height: Kirigami.Units.iconSizes.large
                }

                ColumnLayout {
                    PlasmaComponents3.Label {
                        text: batteryLevel >= 0 ? batteryLevel + "%" : "Unknown"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.8
                        font.bold: true
                    }
                    PlasmaComponents3.Label {
                        text: isCharging ? "Charging" :
                            (batteryLevel === 100 ? "Charged" : "On battery")
                        opacity: 0.8
                    }
                }
            }

            // Progress bar
            PlasmaComponents3.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Math.max(0, batteryLevel)
            }

            // Detailed information in grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing

                // Current
                PlasmaComponents3.Label {
                    text: "Current:"
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: currentAmps !== 0 ?
                        (isCharging ? "+" : "-") + Math.abs(currentAmps).toFixed(2) + " A" :
                        "Unknown"
                }

                // Power
                PlasmaComponents3.Label {
                    text: "Power:"
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: powerWatts > 0.1 ? powerWatts.toFixed(1) + " W" : "Unknown"
                }

                // Voltage
                PlasmaComponents3.Label {
                    text: "Voltage:"
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: voltageVolts > 0 ? voltageVolts.toFixed(1) + " V" : "Unknown"
                }

                // Remaining time
                PlasmaComponents3.Label {
                    text: isCharging ? "Full charge:" : "Battery life:"
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: timeRemaining || "Cannot calculate"
                    color: timeRemaining && timeRemaining.includes("min") ? 
                           Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                }

                // Capacities
                PlasmaComponents3.Label {
                    text: "Capacity:"
                    font.bold: true
                }
                PlasmaComponents3.Label {
                    text: chargeNowAh > 0 && chargeFullAh > 0 ?
                        chargeNowAh.toFixed(1) + " / " + chargeFullAh.toFixed(1) + " Ah" :
                        "Unknown"
                }
            }

            Item { Layout.fillHeight: true }

            // Button to open settings
            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignHCenter
                text: "Power Settings..."
                icon.name: "preferences-system-power-management"
                onClicked: {
                    executable.exec("kcmshell6 kcm_powerdevilprofilesconfig")
                    root.expanded = false
                }
            }
        }
    }
}
