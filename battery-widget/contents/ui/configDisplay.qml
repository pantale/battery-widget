/*
 * Configuration Interface for Advanced Battery Widget
 * 
 * This file provides the configuration UI for the battery widget,
 * allowing users to customize display options, update intervals,
 * and visual preferences through Plasma's settings system.
 * 
 * Features:
 * - Display toggle for battery percentage
 * - Configurable percentage position (left/right of icon)
 * - Battery icon rotation option
 * - Adjustable update interval (1-120 seconds)
 * - Spacing configuration between icon and text
 * - Real-time preview of widget appearance
 * - Technical information about UPower integration
 * 
 * Author: Battery Widget Team
 * License: GPL v3+
 */

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    // ===== CONFIGURATION PROPERTY BINDINGS =====
    // These properties automatically bind to the plasmoid configuration system
    property alias cfg_showPercentage: showPercentage.checked
    property alias cfg_showPercentageLeft: showPercentageLeft.checked
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_rotateBatteryIcon: rotateBatteryIcon.checked
    property alias cfg_batterySpacing: batterySpacing.value

    // ===== GENERAL SETTINGS SECTION =====
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("General Settings")
    }

    /*
     * Main display toggle for battery percentage
     * Controls whether the percentage text is shown alongside the battery icon
     */
    QQC2.CheckBox {
        id: showPercentage
        Kirigami.FormData.label: i18n("Display:")
        text: i18n("Show battery percentage")
//        checked: plasmoid.configuration.showPercentage !== undefined ? plasmoid.configuration.showPercentage : true
    }

    /*
     * Battery icon rotation option
     * Allows users to rotate the battery icon by 180° for different visual preferences
     */
    QQC2.CheckBox {
        id: rotateBatteryIcon
        text: i18n("Rotate battery icon by 180°")
//        checked: plasmoid.configuration.rotateBatteryIcon !== undefined ? plasmoid.configuration.rotateBatteryIcon : false
    }

    // Vertical spacing for visual separation
    Item {
        Layout.preferredHeight: Kirigami.Units.largeSpacing
    }

    /*
     * Update interval configuration
     * Controls how frequently the widget queries UPower for battery data
     * Range: 1-120 seconds with 30-second default
     */
    RowLayout {
        Kirigami.FormData.label: i18n("Update interval:")
        spacing: Kirigami.Units.smallSpacing

        QQC2.SpinBox {
            id: updateInterval
            from: 1                              // Minimum: 1 second
            to: 120                              // Maximum: 120 seconds
            stepSize: 1                          // Increment by 1 second
            value: plasmoid.configuration.updateInterval || 30  // Default: 30 seconds
            textFromValue: function(value) { 
                return value.toString() 
            }
        }

        QQC2.Label {
            text: i18n("seconds")
            color: Kirigami.Theme.textColor
        }
    }

    /*
     * Explanatory text for update interval setting
     * Provides guidance on performance vs accuracy trade-offs
     */
    QQC2.Label {
        Layout.fillWidth: true
        text: i18n("Lower values provide more frequent battery updates but may increase CPU usage.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }

    // Vertical spacing before grouped controls
    Item {
        Layout.preferredHeight: Kirigami.Units.largeSpacing
    }

    // ===== PERCENTAGE POSITION SECTION =====
    /*
     * Grouped controls for percentage text positioning
     * Only enabled when percentage display is active
     */
    QQC2.GroupBox {
        Layout.fillWidth: true
        title: i18n("Battery percentage position")
        enabled: showPercentage.checked  // Disable when percentage is hidden

        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing

            /*
             * Radio button for right-side percentage positioning (default)
             * This is the traditional layout: [ICON] 85%
             */
            QQC2.RadioButton {
                id: showPercentageRight
                text: i18n("Show percentage to the right of icon")
                checked: !showPercentageLeft.checked  // Default position
                onToggled: {
                    if (checked) {
                        showPercentageLeft.checked = false
                    }
                }
            }

            /*
             * Radio button for left-side percentage positioning
             * Alternative layout: 85% [ICON]
             */
            QQC2.RadioButton {
                id: showPercentageLeft
                text: i18n("Show percentage to the left of icon")
                checked: plasmoid.configuration.showPercentageLeft !== undefined ? plasmoid.configuration.showPercentageLeft : false
                onToggled: {
                    if (checked) {
                        showPercentageRight.checked = false
                    }
                }
            }

            // Small spacing before spacing control
            Item {
                Layout.preferredHeight: Kirigami.Units.smallSpacing
            }

            /*
             * Spacing control between icon and percentage text
             * Allows fine-tuning of visual spacing (0-20 pixels)
             */
            RowLayout {
                spacing: Kirigami.Units.smallSpacing

                QQC2.Label {
                    text: i18n("Spacing:")
                }

                QQC2.SpinBox {
                    id: batterySpacing
                    from: 0                          // Minimum: no spacing
                    to: 20                           // Maximum: 20 pixels
                    stepSize: 1                      // Increment by 1 pixel
                    value: plasmoid.configuration.batterySpacing || 5  // Default: 5 pixels
                    textFromValue: function(value) { 
                        return value.toString() 
                    }
                }
                
                QQC2.Label {
                    text: i18n("px")
                    color: Kirigami.Theme.textColor
                }
            }

            /*
             * Help text for spacing configuration
             * Explains the pixel range and its effect
             */
            QQC2.Label {
                Layout.fillWidth: true
                text: i18n("Distance between battery icon and percentage text (0-20 pixels)")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.6
                wrapMode: Text.WordWrap
            }
        }
    }

    // ===== LIVE PREVIEW SECTION =====
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Preview")
    }

    /*
     * Live preview of widget appearance
     * Shows real-time preview of how the widget will look with current settings
     * Includes rotation, spacing, and positioning effects
     */
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.disabledTextColor
        border.width: 1
        radius: 6

        RowLayout {
            anchors.centerIn: parent
            spacing: batterySpacing.value  // Live spacing preview
            // Live layout direction preview
            layoutDirection: showPercentageLeft.checked ? Qt.RightToLeft : Qt.LeftToRight

            /*
             * Preview battery icon with live rotation
             * Uses a representative 60% battery icon for consistent preview
             */
            Kirigami.Icon {
                source: "battery-060"  // Representative battery level for preview
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                // Live rotation preview
                rotation: rotateBatteryIcon.checked ? 180 : 0

                // Smooth rotation animation during configuration changes
                Behavior on rotation {
                    RotationAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            /*
             * Preview percentage text with live visibility
             * Shows/hides based on the percentage display checkbox
             */
            QQC2.Label {
                text: "60%"  // Representative percentage for preview
                visible: showPercentage.checked  // Live visibility preview
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    /*
     * Preview explanation text
     * Describes what users are seeing in the preview and its benefits
     */
    QQC2.Label {
        Layout.fillWidth: true
        text: i18n("This preview shows how your battery widget will appear in the panel.\nThe 180° rotation can be useful for different visual orientations.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }

    // ===== FLEXIBLE SPACER =====
    /*
     * Spacer to push all content to the top of the configuration dialog
     * Ensures proper layout regardless of dialog height
     */
    Item {
        Layout.fillHeight: true
    }
}
