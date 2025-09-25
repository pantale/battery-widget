/*
 * Advanced Battery Widget for KDE Plasma 6
 * 
 * This plasmoid provides comprehensive battery monitoring using UPower,
 * the standard Linux power management service. It offers detailed battery
 * information including health, charge rates, and estimated time remaining.
 * 
 * Features:
 * - Real-time battery monitoring via UPower
 * - Configurable update intervals and display options
 * - Icon rotation and percentage positioning
 * - Detailed battery health and capacity information
 * - Support for both energy (Wh) and charge (Ah) data
 * - Automatic battery device detection
 * - Multi-language decimal format support (comma/dot)
 * 
 * Author: Battery Widget Team
 * License: GPL v3+
 * Dependencies: UPower, Plasma 6, Qt 6
 */

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents3
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    // ===== BATTERY PROPERTIES =====
    // Core battery status and metrics
    property int batteryLevel: -1                    // Battery percentage (0-100, -1 = unknown)
    property bool isCharging: false                  // True when battery is charging
    property real currentAmps: 0.0                   // Current flow in Amperes (+ charging, - discharging)
    property real voltageVolts: 0.0                  // Battery voltage in Volts
    property real powerWatts: 0.0                    // Power consumption/generation in Watts
    property real chargeNowAh: 0.0                   // Current charge capacity in Ampere-hours
    property real chargeFullAh: 0.0                  // Full charge capacity in Ampere-hours
    property real energyFullDesignWh: 0.0            // Original design energy capacity in Watt-hours
    property real energyFullWh: 0.0                  // Current full energy capacity in Watt-hours
    property real energyNowWh: 0.0                   // Current energy level in Watt-hours
    property string timeRemaining: ""                // Formatted time remaining string
    property string batteryDevice: ""                // UPower device path (e.g., /org/freedesktop/UPower/devices/battery_BAT0)
    property string batteryTechnology: ""            // Battery chemistry (Li-ion, Li-Po, etc.)
    property string batteryVendor: ""                // Battery manufacturer
    property string batteryModel: ""                 // Battery model number
    property bool isPresent: false                   // True when battery is physically present

    // ===== CONFIGURATION PROPERTIES =====
    // These bind to Plasmoid.configuration values with sensible defaults
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

    // ===== DYNAMIC PLASMOID PROPERTIES =====
    // These are updated automatically when battery data changes
    Plasmoid.title: formatTitle()
    toolTipMainText: formatTooltipMain()
    toolTipSubText: formatTooltipSub()

    // ===== UPOWER DATA SOURCE =====
    /*
     * This DataSource connects to the 'executable' engine to run UPower commands.
     * UPower is the standard Linux power management daemon that provides detailed
     * battery information through DBus. We use command-line interface for simplicity.
     */
    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        /*
         * Handle data received from UPower commands
         * @param {string} source - The command that was executed
         * @param {object} data - Contains stdout, stderr, and exit code
         */
        onNewData: function(source, data) {
            if (data.stdout) {
                if (source.includes("upower -e")) {
                    // Parse the list of battery devices
                    parseBatteryList(data.stdout)
                } else if (source.includes("upower -i")) {
                    // Parse detailed battery information
                    parseBatteryInfo(data.stdout)
                }
            }
            // Always disconnect after processing to prevent memory leaks
            disconnectSource(source)
        }

        /*
         * Execute UPower command to list battery devices
         * Uses grep to filter only battery devices (BAT*)
         */
        function getBatteryList() {
            connectSource("upower -e | grep BAT")
        }

        /*
         * Execute UPower command to get detailed battery information
         * Uses either a specific device path or auto-detects the first battery
         */
        function getBatteryInfo() {
            if (batteryDevice !== "") {
                connectSource("upower -i " + batteryDevice)
            } else {
                connectSource("upower -i $(upower -e | grep BAT | head -n1)")
            }
        }
    }

    // ===== UPDATE TIMER =====
    /*
     * Periodic timer to refresh battery data from UPower
     * Interval is configurable by the user (1-60 seconds)
     */
    Timer {
        id: updateTimer
        interval: updateInterval * 1000  // Convert seconds to milliseconds
        running: true                    // Start automatically
        repeat: true                     // Run continuously
        triggeredOnStart: true          // Execute immediately on startup
        onTriggered: updateBatteryData()
    }

    // Update timer interval when configuration changes
    onUpdateIntervalChanged: {
        updateTimer.interval = updateInterval * 1000
    }

    // ===== DATA PARSING FUNCTIONS =====

    /*
     * Parse the output of 'upower -e | grep BAT' command
     * Extracts the first battery device path for detailed queries
     * @param {string} output - Raw output from upower -e command
     */
    function parseBatteryList(output) {
        if (!output || output.trim() === "") {
            batteryLevel = -1
            isPresent = false
            return
        }

        var lines = output.trim().split('\n')
        if (lines.length > 0 && lines[0] !== "") {
            batteryDevice = lines[0].trim()
            // Proceed to get detailed battery information
            executable.getBatteryInfo()
        } else {
            batteryLevel = -1
            isPresent = false
        }
    }

    /*
     * Parse the output of 'upower -i <device>' command
     * Extracts all battery properties from UPower's detailed output
     * @param {string} output - Raw output from upower -i command
     */
    function parseBatteryInfo(output) {
        if (!output || output.trim() === "") {
            batteryLevel = -1
            isPresent = false
            return
        }

        var lines = output.trim().split('\n')
        var tempData = {}

        // Parse each line of UPower output into key-value pairs
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (line === "" || !line.includes(':')) continue

            var colonIndex = line.indexOf(':')
            if (colonIndex === -1) continue

            // Normalize key names (lowercase, single spaces)
            var key = line.substring(0, colonIndex).trim().toLowerCase().replace(/\s+/g, ' ')
            var value = line.substring(colonIndex + 1).trim()

            tempData[key] = value
        }

        // Extract and convert the parsed data
        extractBatteryData(tempData)
    }

    /*
     * Extract and convert battery data from parsed UPower output
     * Handles different data formats and units (Wh, Ah, V, W, %)
     * @param {object} data - Parsed key-value pairs from UPower
     */
    function extractBatteryData(data) {
        // ===== BATTERY PRESENCE =====
        // UPower returns "yes"/"no" for boolean values, not "true"/"false"
        isPresent = (data["present"] === "yes")
        if (!isPresent) {
            batteryLevel = -1
            return
        }

        // ===== BATTERY LEVEL (PERCENTAGE) =====
        if (data["percentage"]) {
            var percentStr = data["percentage"].replace('%', '').trim()
            batteryLevel = parseInt(percentStr) || -1
        }

        // ===== CHARGING STATE =====
        var state = data["state"] || ""
        isCharging = (state === "charging")

        // ===== BATTERY METADATA =====
        batteryTechnology = data["technology"] || "Unknown"
        batteryVendor = data["vendor"] || "Unknown"
        batteryModel = data["model"] || "Unknown"

        // ===== ENERGY DATA (PREFERRED) =====
        // Energy values in Watt-hours are more accurate than charge values
        if (data["energy"]) {
            // Handle both comma and dot decimal separators (internationalization)
            var energyStr = data["energy"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyNowWh = parseFloat(energyStr) || 0.0
        }

        if (data["energy-full"]) {
            var energyFullStr = data["energy-full"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyFullWh = parseFloat(energyFullStr) || 0.0
        }

        if (data["energy-full-design"]) {
            var energyFullDesignStr = data["energy-full-design"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            energyFullDesignWh = parseFloat(energyFullDesignStr) || 0.0
        }

        // ===== CHARGE DATA (FALLBACK) =====
        // Charge values in Ampere-hours, used when energy data is unavailable
        if (data["charge"]) {
            var chargeStr = data["charge"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            chargeNowAh = parseFloat(chargeStr) || 0.0
        }

        if (data["charge-full"]) {
            var chargeFullStr = data["charge-full"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            chargeFullAh = parseFloat(chargeFullStr) || 0.0
        }

        // ===== VOLTAGE =====
        if (data["voltage"]) {
            var voltageStr = data["voltage"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            voltageVolts = parseFloat(voltageStr) || 0.0
        }

        // ===== POWER AND CURRENT =====
        if (data["energy-rate"]) {
            // Energy rate is power consumption/generation in Watts
            var energyRateStr = data["energy-rate"].replace(/[^0-9,\.]/g, '').replace(',', '.')
            var energyRate = parseFloat(energyRateStr) || 0.0

            // Calculate approximate current using Ohm's law: P = V * I, therefore I = P / V
            if (voltageVolts > 0) {
                currentAmps = energyRate / voltageVolts
                // Make current negative during discharge for intuitive display
                if (!isCharging && currentAmps > 0) {
                    currentAmps = -currentAmps
                }
            }
            powerWatts = energyRate
        }

        // ===== TIME REMAINING =====
        // Prefer UPower's calculated time estimates over manual calculations
        if (isCharging && data["time to full"]) {
            timeRemaining = data["time to full"]
        } else if (!isCharging && data["time to empty"]) {
            timeRemaining = data["time to empty"]
        } else {
            // Fallback to manual calculation if UPower doesn't provide estimates
            calculateTimeRemaining()
        }

        // Update all dependent properties
        updateDynamicProperties()
    }

    // ===== FORMATTING FUNCTIONS =====

    /*
     * Format a numeric value with units
     * @param {number} value - The numeric value to format
     * @param {string} unit - The unit string (A, V, W, etc.)
     * @param {number} decimals - Number of decimal places
     * @returns {string} Formatted string or "Unknown"
     */
    function formatValue(value, unit, decimals) {
        return value > 0 ? value.toFixed(decimals) + " " + unit : "Unknown"
    }

    /*
     * Format current with appropriate sign indication
     * @returns {string} Formatted current string with +/- prefix
     */
    function formatCurrent() {
        if (Math.abs(currentAmps) < 0.01) return "Unknown"
        var sign = isCharging ? "+" : "-"
        return sign + Math.abs(currentAmps).toFixed(2) + " A"
    }

    /*
     * Format battery capacity information (current/full with percentage)
     * Prefers energy values (Wh) over charge values (Ah)
     * @returns {string} Formatted capacity string
     */
    function formatCapacity() {
        if (energyNowWh > 0 && energyFullWh > 0) {
            var percentage = Math.round((energyNowWh / energyFullWh) * 100)
            return energyNowWh.toFixed(1) + " / " + energyFullWh.toFixed(1) + " Wh (" + percentage + "%)"
        } else if (chargeNowAh > 0 && chargeFullAh > 0) {
            var percentage = Math.round((chargeNowAh / chargeFullAh) * 100)
            return chargeNowAh.toFixed(1) + " / " + chargeFullAh.toFixed(1) + " Ah (" + percentage + "%)"
        }
        return "Unknown"
    }

    /*
     * Format battery health information (current capacity vs original design)
     * @returns {string} Formatted health percentage
     */
    function formatBatteryHealth() {
        if (energyFullWh > 0 && energyFullDesignWh > 0) {
            var healthPercent = Math.round((energyFullWh / energyFullDesignWh) * 100)
            return energyFullWh.toFixed(1) + " / " + energyFullDesignWh.toFixed(1) + " Wh (" + healthPercent + "%)"
        }
        return "Unknown"
    }

    /*
     * Get appropriate battery icon name based on level and charging state
     * @returns {string} Icon name for current battery state
     */
    function getBatteryIconName() {
        if (batteryLevel < 0 || !isPresent) return "battery-missing"

        // Determine icon suffix based on battery level
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

    /*
     * Get appropriate text color based on battery level and charging state
     * @returns {color} Theme-appropriate color
     */
    function getTextColor() {
        if (batteryLevel < 0 || !isPresent) return Kirigami.Theme.disabledTextColor
        if (batteryLevel <= 15 && !isCharging) return Kirigami.Theme.negativeTextColor
        if (batteryLevel <= 25 && !isCharging) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.textColor
    }

    /*
     * Format plasmoid title with battery information
     * @returns {string} Formatted title string
     */
    function formatTitle() {
        if (batteryLevel >= 0 && isPresent) {
            return "Battery " + batteryLevel + "%" + (timeRemaining ? " • " + timeRemaining : "")
        }
        return "Battery unknown"
    }

    /*
     * Format main tooltip text
     * @returns {string} Main tooltip text
     */
    function formatTooltipMain() {
        return batteryLevel >= 0 && isPresent ? "Battery " + batteryLevel + "%" : "Battery unknown"
    }

    /*
     * Format detailed tooltip subtitle with comprehensive battery information
     * @returns {string} Multi-line detailed battery information
     */
    function formatTooltipSub() {
        if (!isPresent) return "No battery detected"

        var parts = []

        // Battery state
        if (isCharging) parts.push("Charging")
        else if (batteryLevel === 100) parts.push("Fully charged")
        else parts.push("On battery")

        // Current information
        if (Math.abs(currentAmps) > 0.01) {
            parts.push((isCharging ? "Charge: +" : "Discharge: -") + 
                      Math.abs(currentAmps).toFixed(2) + " A")
        }

        // Power and voltage
        if (powerWatts > 0.1) parts.push("Power: " + powerWatts.toFixed(1) + " W")
        if (voltageVolts > 0) parts.push("Voltage: " + voltageVolts.toFixed(1) + " V")

        // Time estimates
        if (timeRemaining !== "" && timeRemaining !== "Unknown") {
            parts.push((isCharging ? "Full charge in: " : "Time remaining: ") + timeRemaining)
        }

        // Model information
        if (batteryVendor !== "Unknown" && batteryModel !== "Unknown") {
            parts.push("Model: " + batteryVendor + " " + batteryModel)
        }

        return parts.join("\n")
    }

    // ===== CORE UPDATE FUNCTIONS =====

    /*
     * Main function to update all battery information via UPower
     * This is called by the timer and triggers the entire data refresh cycle
     */
    function updateBatteryData() {
        // Start the data refresh cycle by getting the battery device list
        executable.getBatteryList()
    }

    /*
     * Calculate time remaining using energy/power or charge/current data
     * This is a fallback when UPower doesn't provide time estimates
     */
    function calculateTimeRemaining() {
        var timeHours = 0.0

        // Prefer energy-based calculations (more accurate)
        if (powerWatts > 0.1) {
            if (isCharging) {
                // Time to reach full charge
                timeHours = (energyFullWh - energyNowWh) / powerWatts
            } else {
                // Time until empty
                timeHours = energyNowWh / powerWatts
            }
        } else if (Math.abs(currentAmps) > 0.01) {
            // Fallback to charge-based calculations
            if (isCharging) {
                timeHours = (chargeFullAh - chargeNowAh) / Math.abs(currentAmps)
            } else {
                timeHours = chargeNowAh / Math.abs(currentAmps)
            }
        } else {
            timeRemaining = "Cannot calculate"
            return
        }

        // Format time into human-readable format
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

    /*
     * Update all dynamic properties that depend on battery data
     * This ensures consistent updates across the plasmoid interface
     */
    function updateDynamicProperties() {
        Plasmoid.title = formatTitle()
        toolTipMainText = formatTooltipMain()
        toolTipSubText = formatTooltipSub()
    }

    // ===== COMPACT REPRESENTATION =====
    /*
     * The compact view shown in the system tray
     * Features configurable icon rotation, percentage positioning, and spacing
     */
    compactRepresentation: Item {
        Layout.preferredWidth: batteryRow.implicitWidth
        Layout.preferredHeight: batteryRow.implicitHeight
        Layout.minimumWidth: batteryRow.implicitWidth
        Layout.minimumHeight: Layout.preferredHeight

        RowLayout {
            id: batteryRow
            anchors.centerIn: parent
            spacing: batterySpacing  // User-configurable spacing
            // Dynamic layout direction based on percentage position setting
            layoutDirection: showPercentageLeft ? Qt.RightToLeft : Qt.LeftToRight

            // Battery icon with rotation and charging animation
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

                // Charging animation - pulsing effect when battery is charging
                SequentialAnimation on opacity {
                    running: isCharging && batteryLevel < 100 && isPresent
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

            // Battery percentage text with configurable visibility and positioning
            PlasmaComponents3.Label {
                text: batteryLevel >= 0 && isPresent ? batteryLevel + "%" : "?"
                color: getTextColor()
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
                font.bold: batteryLevel <= 15 && !isCharging && isPresent  // Bold for low battery warning
                visible: showPercentage  // User-configurable visibility
            }
        }

        // Click handler for detailed information
        MouseArea {
            anchors.fill: parent
            hoverEnabled: false // Disable to use standard tooltip
            onClicked: {
                // Placeholder for future detailed popup or action
                root.expanded = !root.expanded
            }
        }
    }

    // ===== FULL REPRESENTATION =====
    /*
     * The expanded view shown when the widget is enlarged
     * Displays comprehensive battery information in a structured layout
     */
    fullRepresentation: PlasmaComponents3.Page {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 18

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // Header with battery icon and status
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.largeSpacing

                // Large battery icon with rotation support
                Kirigami.Icon {
                    source: getBatteryIconName()
                    width: Kirigami.Units.iconSizes.large
                    height: Kirigami.Units.iconSizes.large
                    rotation: rotateBatteryIcon ? 180 : 0
                    Behavior on rotation {
                        RotationAnimation { duration: 300; easing.type: Easing.InOutQuad }
                    }
                }

                // Battery level and status text
                ColumnLayout {
                    PlasmaComponents3.Label {
                        text: batteryLevel >= 0 && isPresent ? batteryLevel + "%" : "Unknown"
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 2.2
                        font.bold: true
                        color: getTextColor()
                    }
                    PlasmaComponents3.Label {
                        text: !isPresent ? "❌ No battery" :
                              (isCharging ? "🔌 Charging" :
                              (batteryLevel === 100 ? "✓ Fully charged" : "🔋 On battery"))
                        opacity: 0.9
                        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.1
                    }
                }
            }

            // Progress bar showing battery level
            PlasmaComponents3.ProgressBar {
                Layout.fillWidth: true
                from: 0
                to: 100
                value: Math.max(0, batteryLevel)
            }

            // Detailed information grid
            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing

                // Current flow
                PlasmaComponents3.Label { text: "⚡ Current:"; font.bold: true }
                PlasmaComponents3.Label { text: formatCurrent() }

                // Power consumption/generation
                PlasmaComponents3.Label { text: "💡 Power:"; font.bold: true }
                PlasmaComponents3.Label { text: formatValue(powerWatts, "W", 1) }

                // Battery voltage
                PlasmaComponents3.Label { text: "🔌 Voltage:"; font.bold: true }
                PlasmaComponents3.Label { text: formatValue(voltageVolts, "V", 1) }

                // Time remaining or time to full charge
                PlasmaComponents3.Label { 
                    text: isCharging ? "⏱️ Full charge:" : "⏰ Time remaining:"
                    font.bold: true 
                }
                PlasmaComponents3.Label {
                    text: timeRemaining || "Cannot calculate"
                    color: timeRemaining && timeRemaining.includes("min") ? 
                           Kirigami.Theme.neutralTextColor : Kirigami.Theme.textColor
                }

                // Battery capacity (current vs full)
                PlasmaComponents3.Label { text: "🔋 Capacity:"; font.bold: true }
                PlasmaComponents3.Label { text: formatCapacity() }

                // Battery health (current vs design capacity)
                PlasmaComponents3.Label { text: "🏥 Health:"; font.bold: true }
                PlasmaComponents3.Label { text: formatBatteryHealth() }

                // Battery model and vendor information
                PlasmaComponents3.Label { text: "📋 Model:"; font.bold: true }
                PlasmaComponents3.Label { 
                    text: (batteryVendor !== "Unknown" ? batteryVendor + " " : "") + 
                          (batteryModel !== "Unknown" ? batteryModel : "Unknown") +
                          (batteryTechnology !== "Unknown" ? " (" + batteryTechnology + ")" : "")
                }
            }

            // Spacer to push content to top
            Item { Layout.fillHeight: true }

            // Manual refresh button for troubleshooting
            PlasmaComponents3.Button {
                Layout.alignment: Qt.AlignHCenter
                text: "🔄 Refresh Data"
                onClicked: updateBatteryData()
            }
        }
    }
}