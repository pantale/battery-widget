# Advanced Battery Widget for KDE Plasma 6

A comprehensive battery monitoring widget for KDE Plasma 6 that provides detailed battery information using UPower, the standard Linux power management service.

## Features

- **Real-time battery monitoring** via UPower integration
- **Detailed battery metrics**: current, voltage, power consumption, time remaining
- **Battery health monitoring**: current vs original capacity comparison
- **Configurable display options**: percentage position, icon rotation, spacing
- **Multi-language decimal format support** (comma/dot separators)
- **Automatic battery device detection**
- **Charging animations** and visual feedback
- **Comprehensive tooltip** with technical details


## Requirements

- **KDE Plasma 6.x** (developed specifically for Plasma 6)
- **UPower** (usually pre-installed on most Linux distributions)
- **Qt 6** and **KDE Frameworks 6**

## Installation

### Using kpackagetool6 (Recommended)

```bash
# Install the widget
kpackagetool6 --type Plasma/Applet --install battery-widget
```

### Manual Installation

```bash
# Copy to local Plasma directory
cp -r battery-widget ~/.local/share/plasma/plasmoids
```

## Uninstallation

```bash
# Using kpackagetool6
kpackagetool6 --type Plasma/Applet --remove battery.widget

# Manual removal
rm -rf ~/.local/share/plasma/plasmoids/battery.widget
```


## Usage

1. Right-click on desktop or panel
2. Select "Add Widgets"
3. Search for "Advanced Battery Widget"
4. Drag to desired location
5. Right-click widget → "Configure" for settings

## Technical Information

### UPower Integration

This widget uses **UPower** instead of directly reading `/sys/class/power_supply/` files, providing:

- **Standardized data access** across different hardware
- **Robust battery detection** and automatic device discovery
- **Accurate time calculations** and health monitoring
- **Multi-language decimal format support**


### Data Sources

- **Energy values**: Watt-hours (Wh) for precise capacity measurements
- **Charge values**: Ampere-hours (Ah) as fallback
- **Real-time metrics**: Current flow, voltage, power consumption
- **Battery metadata**: Vendor, model, technology type


### Configuration Options

- Update interval: 1-60 seconds (default: 2s)
- Percentage display toggle and positioning
- Icon rotation (180°) for visual preferences
- Adjustable spacing between icon and text


## Development

### File Structure

```
battery-widget/
├── contents/
│   ├── ui/
│   │   ├── main.qml              # Main widget logic
│   │   └── configDisplay.qml     # Configuration interface
│   └── config/
│       ├── main.xml              # Configuration schema
│       └── config.qml            # Configuration tabs
└── metadata.json                 # Widget metadata
```


### Dependencies

- **Plasma5Support.DataSource**: For UPower command execution
- **Kirigami Components**: UI theming and layout
- **PlasmaComponents3**: Native Plasma controls


## License

GPL v3+ - see LICENSE file for details

## Contributing

Contributions are welcome! Please ensure code follows existing patterns and includes appropriate documentation.

***

**Note**: This widget is specifically developed for **KDE Plasma 6.x** and requires UPower for battery data retrieval. For older Plasma versions, consider alternative battery widgets.
