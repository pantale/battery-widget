import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // Core battery properties
    property int batteryLevel: -1
    property bool isCharging: false
    property real currentAmps: 0.0
    property real voltageVolts: 0.0
    property real powerWatts: 0.0
    property real chargeNowAh: 0.0
    property real chargeFullAh: 0.0
    property string timeRemaining: ""
    property string batteryPath: "/sys/class/power_supply/BAT0"

    // Configuration properties from Plasmoid.configuration
    property bool showPercentage: Plasmoid.configuration.showPercentage !== undefined ? 
                                  Plasmoid.configuration.showPercentage : true
    property bool showPercentageLeft: Plasmoid.configuration.showPercentageLeft !== undefined ? 
                                      Plasmoid.configuration.showPercentageLeft : false
    property bool rotateBatteryIcon: Plasmoid.configuration.rotateBatteryIcon !== undefined ? 
                                     Plasmoid.configuration.rotateBatteryIcon : false
    property int updateInterval: Plasmoid.configuration.updateInterval !== undefined ? 
                                 Plasmoid.configuration.updateInterval : 2
    property int batterySpacing: Plasmoid.configuration.batterySpacing !== undefined ? 
                                 Plasmoid.configuration.batterySpacing : Kirigami.Units.smallSpacing

    // Dynamic plasmoid configuration
    Plasmoid.title: formatTitle()
    toolTipMainText: formatTooltipMain()
    toolTipSubText: formatTooltipSub()

    // System command executor - simplified usage
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []
        onNewData: function(source, data) { disconnectSource(source) }
        function exec(cmd) { executable.connectSource(cmd) }
    }

    // Battery data update timer - uses configuration interval
    Timer {
        id: updateTimer
        interval: updateInterval * 1000  // Convert seconds to milliseconds
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updateBatteryData()
    }

    // Update timer interval when configuration changes
    onUpdateIntervalChanged: {
        updateTimer.interval = updateInterval * 1000
    }

    // UTILITY FUNCTIONS - Centralized and optimized

    /**
     * Read system file content safely
     * @param {string} path - File system path to read
     * @returns {string} File content or empty string on error
     */
    function readSystemFile(path) {
        var request = new XMLHttpRequest()
        request.open('GET', 'file://' + path, false)
        try {
            request.send()
            if (request.status === 200) {
                return request.responseText.trim()
            }
        } catch (e) {
            // Silent fail for inaccessible files
        }
        return ""
    }

    /**
     * Auto-discover battery path from common locations
     * @returns {boolean} True if battery found, false otherwise
     */
    function findBatteryPath() {
        var testPaths = [
            "/sys/class/power_supply/BAT0",
            "/sys/class/power_supply/BAT1", 
            "/sys/class/power_supply/BATT"
        ]

        for (var i = 0; i < testPaths.length; i++) {
            if (readSystemFile(testPaths[i] + "/capacity") !== "") {
                batteryPath = testPaths[i]
                return true
            }
        }
        return false
    }

    /**
     * Format numerical value with unit - prevents code duplication
     * @param {number} value - The numerical value
     * @param {string} unit - Unit string (A, V, W, etc.)
     * @param {number} decimals - Number of decimal places
     * @returns {string} Formatted string or "Unknown"
     */
    function formatValue(value, unit, decimals) {
        return value > 0 ? value.toFixed(decimals) + " " + unit : "Unknown"
    }

    /**
     * Format current with sign indication
     * @returns {string} Formatted current string
     */
    function formatCurrent() {
        if (currentAmps === 0) return "Unknown"
        var sign = isCharging ? "+" : "-"
        return sign + Math.abs(currentAmps).toFixed(2) + " A"
    }

    /**
     * Format capacity information
     * @returns {string} Current/Full capacity with percentage
     */
    function formatCapacity() {
        if (chargeNowAh <= 0 || chargeFullAh <= 0) return "Unknown"
        var percentage = Math.round((chargeNowAh / chargeFullAh) * 100)
        return chargeNowAh.toFixed(1) + " / " + chargeFullAh.toFixed(1) + " Ah (" + percentage + "%)"
    }

    /**
     * Get appropriate battery icon based on level and charging state
     * @returns {string} Icon name for current battery state
     */
    function getBatteryIconName() {
        if (batteryLevel < 0) return "battery-missing"

        // Determine level-based icon suffix
        var levelSuffix = "100"
        if (batteryLevel <= 10) levelSuffix = "010"
        else if (batteryLevel <= 20) levelSuffix = "020"
        else if (batteryLevel <= 30) levelSuffix = "030"
        else if (batteryLevel <= 40) levelSuffix = "040"
        else if (batteryLevel <= 50) levelSuffix = "050"
        else if (batteryLevel <= 60) levelSuffix = "060"
        else if (batteryLevel <= 70) levelSuffix = "070"
        else if (batteryLevel <= 80) levelSuffix = "080"
        else if (batteryLevel <= 90) levelSuffix = "090"

        var iconName = "battery-" + levelSuffix
        if (isCharging) iconName += "-charging"
        
        return iconName
    }

    /**
     * Get text color based on battery level and charging state
     * @returns {color} Appropriate text color
     */
    function getTextColor() {
        if (batteryLevel < 0) return Kirigami.Theme.disabledTextColor
        if (batteryLevel <= 15 && !isCharging) return Kirigami.Theme.negativeTextColor
        if (batteryLevel <= 25 && !isCharging) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }

    /**
     * Format plasmoid title with battery info
     * @returns {string} Formatted title
     */
    function formatTitle() {
        return batteryLevel >= 0 ? 
            "Battery " + batteryLevel + "% • " + timeRemaining :
            "Battery Unknown"
    }

    /**
     * Format tooltip main text
     * @returns {string} Main tooltip text
     */
    function formatTooltipMain() {
        return batteryLevel >= 0 ? "Battery " + batteryLevel + "%" : "Battery Unknown"
    }

    /**
     * Format detailed tooltip subtitle
     * @returns {string} Detailed battery information
     */
    function formatTooltipSub() {
        var parts = []

        // Battery status
        if (isCharging) parts.push("Charging")
        else if (batteryLevel === 100) parts.push("Fully charged")
        else parts.push("On battery")

        // Current information
        if (currentAmps !== 0) {
            parts.push((isCharging ? "Charge: +" : "Discharge: -") + 
                      Math.abs(currentAmps).toFixed(2) + " A")
        }

        // Power and voltage
        if (powerWatts > 0.1) parts.push("Power: " + powerWatts.toFixed(1) + " W")
        if (voltageVolts > 0) parts.push("Voltage: " + voltageVolts.toFixed(1) + " V")

        // Time estimation
        if (timeRemaining !== "") {
            parts.push((isCharging ? "Full charge in: " : "Remaining time: ") + timeRemaining)
        }

        return parts.join("\n")
    }

    // MAIN DATA UPDATE FUNCTION

    /**
     * Main function to update all battery information from system files
     * Consolidates all data reading and calculation logic
     */
    function updateBatteryData() {
        // Auto-discover battery path on first run
        if (batteryLevel === -1 && !findBatteryPath()) {
            return // No battery found
        }

        // Read basic battery level
        var capacityStr = readSystemFile(batteryPath + "/capacity")
        if (capacityStr === "") {
            batteryLevel = -1
            return
        }
        batteryLevel = parseInt(capacityStr)

        // Read charging status
        var status = readSystemFile(batteryPath + "/status")
        isCharging = (status === "Charging")

        // Read electrical properties with unit conversion (micro to standard units)
        var currentStr = readSystemFile(batteryPath + "/current_now")
        currentAmps = currentStr !== "" ? parseInt(currentStr) / 1000000.0 : 0.0

        var voltageStr = readSystemFile(batteryPath + "/voltage_now")
        voltageVolts = voltageStr !== "" ? parseInt(voltageStr) / 1000000.0 : 0.0

        // Calculate or read power
        var powerStr = readSystemFile(batteryPath + "/power_now")
        if (powerStr !== "") {
            powerWatts = parseInt(powerStr) / 1000000.0
        } else if (currentAmps !== 0 && voltageVolts !== 0) {
            powerWatts = Math.abs(voltageVolts * currentAmps)
        } else {
            powerWatts = 0.0
        }

        // Read capacity information for time calculation
        var chargeNowStr = readSystemFile(batteryPath + "/charge_now")
        var chargeFullStr = readSystemFile(batteryPath + "/charge_full")
        if (chargeNowStr !== "" && chargeFullStr !== "") {
            chargeNowAh = parseInt(chargeNowStr) / 1000000.0
            chargeFullAh = parseInt(chargeFullStr) / 1000000.0
            calculateTimeRemaining()
        } else {
            timeRemaining = "Unknown time"
        }

        // Update dynamic properties
        updateDynamicProperties()
    }

    /**
     * Calculate remaining time using Linux power management formulas
     * Handles both charging and discharging scenarios
     */
    function calculateTimeRemaining() {
        if (currentAmps === 0) {
            timeRemaining = "Cannot calculate"
            return
        }

        var timeHours = 0.0
        if (isCharging) {
            // Time to reach full charge: (CHARGE_FULL - CHARGE_NOW) / CURRENT_NOW
            timeHours = (chargeFullAh - chargeNowAh) / Math.abs(currentAmps)
        } else {
            // Discharge time: CHARGE_NOW / CURRENT_NOW
            timeHours = chargeNowAh / Math.abs(currentAmps)
        }

        // Format time in human-readable format
        if (timeHours < 0.01) {
            timeRemaining = "< 1 min"
        } else if (timeHours >= 24) {
            timeRemaining = Math.floor(timeHours / 24) + "d " + Math.floor(timeHours % 24) + "h"
        } else if (timeHours >= 1) {
            var hours = Math.floor(timeHours)
            var minutes = Math.floor((timeHours - hours) * 60)
            timeRemaining = hours + "h " + minutes + "min"
        } else {
            timeRemaining = Math.floor(timeHours * 60) + " min"
        }
    }

    /**
     * Update all dynamic properties that depend on battery data
     * Centralized to avoid scattered updates throughout the code
     */
    function updateDynamicProperties() {
        Plasmoid.title = formatTitle()
        toolTipMainText = formatTooltipMain()
        toolTipSubText = formatTooltipSub()
    }

    // REUSABLE COMPONENTS

    /**
     * Reusable component for displaying battery information in a grid
     * Eliminates code duplication between popup and fullRepresentation
     */
    component BatteryInfoGrid: GridLayout {
        columns: 2
        columnSpacing: Kirigami.Units.largeSpacing
        rowSpacing: Kirigami.Units.largeSpacing

        // Current display
        PlasmaComponents3.Label {
            text: "⚡ Current:"
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }
        PlasmaComponents3.Label {
            text: formatCurrent()
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            color: currentAmps !== 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }

        // Power display
        PlasmaComponents3.Label {
            text: "💡 Power:"
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }
        PlasmaComponents3.Label {
            text: formatValue(powerWatts, "W", 1)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            color: powerWatts > 0.1 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }

        // Voltage display
        PlasmaComponents3.Label {
            text: "🔌 Voltage:"
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }
        PlasmaComponents3.Label {
            text: formatValue(voltageVolts, "V", 1)
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            color: voltageVolts > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }

        // Time remaining display
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

        // Capacity display
        PlasmaComponents3.Label {
            text: "🔋 Capacity:"
            font.bold: true
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
        }
        PlasmaComponents3.Label {
            text: formatCapacity()
            font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
            color: chargeNowAh > 0 ? Kirigami.Theme.textColor : Kirigami.Theme.disabledTextColor
        }
    }

    /**
     * Reusable battery header component with icon and status
     * Used in both popup and full representation - includes rotation support
     */
    component BatteryHeader: RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            source: getBatteryIconName()
            width: Kirigami.Units.iconSizes.large
            height: Kirigami.Units.iconSizes.large
            
            // Apply rotation based on configuration
            rotation: rotateBatteryIcon ? 180 : 0
            
            // Smooth rotation animation when configuration changes
            Behavior on rotation {
                RotationAnimation {
                    duration: 300
                    easing.type: Easing.InOutQuad
                }
            }
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

    // DETAILED POPUP DIALOG

    PlasmaCore.Dialog {
        id: detailsPopup
        type: PlasmaCore.Dialog.PopupMenu
        location: PlasmaCore.Types.Floating
        hideOnWindowDeactivate: true

        ColumnLayout {
            width: Kirigami.Units.gridUnit * 18
            height: Kirigami.Units.gridUnit * 14
            spacing: Kirigami.Units.largeSpacing

            // Reusable header component with rotation support
            BatteryHeader {}

            // Progress bar with visual feedback
            PlasmaComponents3.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Math.max(0, batteryLevel)

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.width: 1
                    border.color: Kirigami.Theme.disabledTextColor
                    opacity: 0.3
                    radius: 3
                }
            }

            // Reusable information grid
            BatteryInfoGrid {}

            Item { Layout.fillHeight: true }

            // Action buttons
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                PlasmaComponents3.Button {
                    text: "Close"
                    icon.name: "window-close"
                    onClicked: detailsPopup.visible = false
                }

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

        function showPopup() { visible = true }
    }

    // COMPACT REPRESENTATION - Optimized with configurable position, rotation and spacing

    compactRepresentation: Item {
        Layout.preferredWidth: batteryRow.implicitWidth
        Layout.preferredHeight: batteryRow.implicitHeight
        Layout.minimumWidth: batteryRow.implicitWidth
        Layout.minimumHeight: Layout.preferredHeight

        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: batterySpacing  // Use configurable spacing instead of fixed Kirigami.Units.smallSpacing
            // Dynamic layout direction based on configuration
            layoutDirection: showPercentageLeft ? Qt.RightToLeft : Qt.LeftToRight

            // Animated battery icon with rotation support
            Kirigami.Icon {
                source: getBatteryIconName()
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                color: getTextColor()
                
                // Apply rotation based on configuration
                rotation: rotateBatteryIcon ? 180 : 0
                
                // Smooth rotation animation when configuration changes
                Behavior on rotation {
                    RotationAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }

                // Charging animation - pulsing effect
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

            // Battery percentage text - visibility and position controlled by configuration
            PlasmaComponents3.Label {
                text: batteryLevel >= 0 ? batteryLevel + "%" : "?"
                color: getTextColor()
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: batteryLevel <= 15 && !isCharging
                visible: showPercentage  // Configuration-controlled visibility
            }
        }

        // Click handler for popup toggle
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false // Disabled to use standard tooltip
            onClicked: {
                if (detailsPopup.visible) {
                    detailsPopup.visible = false
                } else {
                    detailsPopup.showPopup()
                }
            }
        }
    }

    // FULL REPRESENTATION - Used when widget is expanded

    fullRepresentation: PlasmaComponents3.Page {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 18
        Layout.preferredHeight: Kirigami.Units.gridUnit * 16

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Reusable header component with rotation support
            BatteryHeader {}

            // Progress bar
            PlasmaComponents3.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Math.max(0, batteryLevel)
            }

            // Reusable information grid (simplified for full view)
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing

                PlasmaComponents3.Label { text: "Current:"; font.bold: true }
                PlasmaComponents3.Label { text: formatCurrent() }

                PlasmaComponents3.Label { text: "Power:"; font.bold: true }
                PlasmaComponents3.Label { text: formatValue(powerWatts, "W", 1) }

                PlasmaComponents3.Label { text: "Voltage:"; font.bold: true }
                PlasmaComponents3.Label { text: formatValue(voltageVolts, "V", 1) }

                PlasmaComponents3.Label { 
                    text: isCharging ? "Full charge:" : "Battery life:"
                    font.bold: true 
                }
                PlasmaComponents3.Label {
                    text: timeRemaining || "Cannot calculate"
                    color: timeRemaining && timeRemaining.includes("min") ? 
                           Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                }

                PlasmaComponents3.Label { text: "Capacity:"; font.bold: true }
                PlasmaComponents3.Label { text: formatCapacity() }
            }

            Item { Layout.fillHeight: true }

            // Settings button
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

