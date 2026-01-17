# WhisprMute

A macOS menu bar app that automatically mutes your microphone in meeting apps when Wispr Flow is actively recording, then unmutes when done.

## Features

- **Automatic Muting**: Detects when Wispr Flow starts using the microphone and automatically mutes supported meeting apps
- **Smart Restoration**: Only unmutes apps that were unmuted before muting - preserves your intentional mute states
- **Menu Bar Integration**: Clean menu bar icon with status indication
- **Per-App Control**: Enable/disable automatic muting for each meeting app individually
- **Multiple App Support**: Works with Zoom, Discord, Slack, Microsoft Teams, Google Meet, Webex, and Skype

## Supported Meeting Apps

| App | Mute Method |
|-----|-------------|
| Zoom | Menu bar control via AppleScript |
| Discord | Keyboard shortcut (Cmd+Shift+M) |
| Slack | Keyboard shortcut (M in huddle) |
| Microsoft Teams | Keyboard shortcut (Cmd+Shift+M) |
| Google Meet | Browser tab detection + Cmd+D |
| Webex | Keyboard shortcut (Ctrl+M) |
| Skype | Keyboard shortcut (Cmd+Shift+M) |

## Requirements

- macOS 13.0 or later
- Xcode 15.0 or later (for building)

## Installation

### Building from Source

1. Clone the repository:
   ```bash
   git clone git@github.com:ItsDlylan/WhisprMute.git
   cd WhisprMute
   ```

2. Open the project in Xcode:
   ```bash
   open WhisprMute.xcodeproj
   ```

3. Build and run (Cmd+R)

### Required Permissions

WhisprMute needs the following permissions to function:

1. **Accessibility**: Required to control mute buttons in other apps
   - Go to System Settings > Privacy & Security > Accessibility
   - Add WhisprMute to the list

2. **Automation**: Required to send commands to meeting apps
   - macOS will prompt you when WhisprMute first tries to control each app
   - Click "OK" to allow

## Usage

1. Launch WhisprMute - it will appear in your menu bar
2. Click the menu bar icon to see the current status
3. Enable/disable the feature with the toggle
4. Start a meeting in any supported app
5. When you activate Wispr Flow dictation:
   - Your meeting apps will automatically mute
   - The menu bar icon will change to indicate active muting
6. When dictation completes:
   - Apps that were unmuted will be restored to unmuted
   - Apps that were already muted will stay muted

## Architecture

```
WhisprMute/
├── App/
│   ├── WhisprMuteApp.swift      # Main app entry
│   └── AppDelegate.swift        # Menu bar setup & coordination
├── Core/
│   ├── MicrophoneMonitor.swift  # Core Audio mic monitoring
│   ├── WisprFlowDetector.swift  # Wispr Flow activity detection
│   └── MeetingAppController.swift # Mute/unmute orchestration
├── MeetingApps/
│   ├── MeetingApp.swift         # Protocol for meeting apps
│   ├── ZoomController.swift     # Zoom-specific mute
│   ├── DiscordController.swift  # Discord-specific mute
│   ├── SlackController.swift    # Slack-specific mute
│   ├── TeamsController.swift    # Teams-specific mute
│   ├── GoogleMeetController.swift # Meet-specific mute
│   ├── WebexController.swift    # Webex-specific mute
│   └── SkypeController.swift    # Skype-specific mute
├── UI/
│   ├── MenuBarView.swift        # Menu bar icon and menu
│   └── SettingsView.swift       # Settings window
└── Resources/
    ├── Assets.xcassets          # Icons
    ├── Info.plist               # App configuration
    └── WhisprMute.entitlements  # App permissions
```

## How It Works

1. **Microphone Monitoring**: Uses Core Audio APIs and process detection to monitor which applications are using the microphone

2. **Wispr Flow Detection**: Specifically watches for the "Wispr Flow" process using the microphone, indicating dictation has begun

3. **Meeting App Control**: When Wispr Flow activates:
   - Stores current mute state of each running meeting app
   - Mutes all meeting apps that were unmuted
   - When Wispr Flow stops, restores previous mute states

## Troubleshooting

### App not muting correctly

1. Ensure WhisprMute has Accessibility permissions
2. Try the "Open Settings" button in the Permissions tab
3. Remove and re-add WhisprMute from Accessibility list

### Wispr Flow not detected

1. Make sure Wispr Flow is running
2. Ensure Wispr Flow is using the microphone when dictating
3. Check that WhisprMute's monitoring is enabled (toggle in menu bar dropdown)

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
