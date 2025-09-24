import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page
    
    // Configuration properties binding
    property alias cfg_showPercentage: showPercentage.checked
    property alias cfg_showPercentageLeft: showPercentageLeft.checked
    property alias cfg_updateInterval: updateInterval.value
    property alias cfg_rotateBatteryIcon: rotateBatteryIcon.checked

    // GENERAL SETTINGS SECTION
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("General Settings")
    }

    QQC2.CheckBox {
        id: showPercentage
        Kirigami.FormData.label: i18n("Display:")
        text: i18n("Show battery percentage")
    }
    
    QQC2.CheckBox {
        id: rotateBatteryIcon
        text: i18n("Rotate battery icon by 180°")
    }
    
    RowLayout {
        Kirigami.FormData.label: i18n("Update interval:")
        spacing: Kirigami.Units.smallSpacing
        
        QQC2.SpinBox {
            id: updateInterval
            from: 1
            to: 60
            stepSize: 1
        }
        
        QQC2.Label {
            text: i18n("seconds")
            color: Kirigami.Theme.textColor
        }
    }
    
    QQC2.Label {
        Layout.fillWidth: true
        text: i18n("Lower values provide more frequent battery updates but may increase CPU usage.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }

    // POSITION SETTINGS SECTION
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Position Settings")
    }

    QQC2.GroupBox {
        Layout.fillWidth: true
        title: i18n("Battery Percentage Position")
        enabled: showPercentage.checked
        
        ColumnLayout {
            anchors.fill: parent
            spacing: Kirigami.Units.smallSpacing
            
            QQC2.RadioButton {
                id: showPercentageRight
                text: i18n("Show percentage on the right of icon")
                checked: !page.cfg_showPercentageLeft
                onToggled: {
                    if (checked) {
                        page.cfg_showPercentageLeft = false
                    }
                }
            }
            
            QQC2.RadioButton {
                id: showPercentageLeft
                text: i18n("Show percentage on the left of icon")
                checked: page.cfg_showPercentageLeft
                onToggled: {
                    if (checked) {
                        page.cfg_showPercentageLeft = true
                    }
                }
            }
        }
    }

    // PREVIEW SECTION
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: i18n("Preview")
    }

    // Live preview of the widget appearance with rotation
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: Kirigami.Units.gridUnit * 2
        color: Kirigami.Theme.backgroundColor
        border.color: Kirigami.Theme.disabledTextColor
        border.width: 1
        radius: 6

        RowLayout {
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing
            layoutDirection: showPercentageLeft.checked ? Qt.RightToLeft : Qt.LeftToRight

            Kirigami.Icon {
                source: "battery-060"
                width: Kirigami.Units.iconSizes.small
                height: Kirigami.Units.iconSizes.small
                // Apply rotation based on configuration
                rotation: rotateBatteryIcon.checked ? 180 : 0
                
                // Smooth rotation animation when toggling
                Behavior on rotation {
                    RotationAnimation {
                        duration: 300
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            QQC2.Label {
                text: "60%"
                visible: showPercentage.checked
                font.pixelSize: Kirigami.Theme.smallFont.pixelSize
            }
        }
    }

    QQC2.Label {
        Layout.fillWidth: true
        text: i18n("This preview shows how your battery widget will appear in the panel. The 180° rotation can be useful for different visual orientations.")
        font.pointSize: Kirigami.Theme.smallFont.pointSize
        opacity: 0.6
        wrapMode: Text.WordWrap
        Layout.maximumWidth: Kirigami.Units.gridUnit * 25
    }

    // Spacer to push content to top
    Item {
        Layout.fillHeight: true
    }
}

