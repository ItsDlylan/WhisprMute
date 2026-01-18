# WhisprMute

A macOS menu bar app that automatically mutes your microphone in meeting apps when [Wispr Flow](https://wispr.com) is actively recording, then unmutes when done.

## The Problem

You're a developer in a meeting, but you also need to get work done. You use Wispr Flow to dictate code, messages, or notes - but every time you start dictating, your teammates hear you talking to your AI assistant. You have to remember to mute yourself first, then unmute after. It's disruptive and easy to forget.

## The Solution

WhisprMute runs silently in your menu bar and automatically:
1. Detects when Wispr Flow starts recording (in real-time via macOS system logs)
2. Instantly mutes your microphone in your meeting apps
3. Unmutes when you're done dictating

No manual muting. No embarrassing moments. Just seamless dictation while in meetings.

## Supported Meeting Apps

| App | Status | Mute Method |
|-----|--------|-------------|
| Discord | **Fully Supported** | Discord RPC API (native integration) |
| Google Meet | **Fully Supported** | Chrome DevTools Protocol (no focus stealing) |
| Zoom | In Development | Coming soon |
| Slack | Planned | - |
| Microsoft Teams | Planned | - |
| Webex | Planned | - |
| Skype | Planned | - |

## Requirements

- macOS 14.0 (Sonoma) or later
- [Wispr Flow](https://wispr.com) installed
- Discord desktop app (for Discord support)

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

### Discord Setup

WhisprMute uses Discord's RPC API for native mute control. You'll need to set up a Discord application:

1. Go to [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a new application
3. Copy your **Application ID** and **Client Secret** from OAuth2
4. Add `http://localhost` as a redirect URI in OAuth2 settings
5. Create a config file at `~/.whisprmute`:
   ```
   DISCORD_CLIENT_ID=your_application_id
   DISCORD_CLIENT_SECRET=your_client_secret
   ```
6. On first run, Discord will prompt you to authorize WhisprMute

### Google Meet Setup

Google Meet runs in Chrome and requires Chrome's DevTools Protocol for focus-free muting. This allows WhisprMute to mute Meet without stealing focus from your current app (critical for Wispr Flow to maintain input context).

**Important:** Chrome 136+ blocks remote debugging on the default profile for security reasons. WhisprMute handles this by creating a separate debug profile with your data cloned.

**Setup via WhisprMute Settings (Recommended)**

1. Open WhisprMute Settings > Permissions tab
2. Select your Chrome profile from the dropdown
3. Click "Setup Debug Mode"
4. Grant Camera and Microphone permissions when prompted
5. WhisprMute will clone your profile (settings, bookmarks, passwords, history, extensions, login sessions) and launch Chrome with debug mode enabled

**What gets copied:**
- Preferences and settings
- Bookmarks
- Saved passwords
- Browsing history
- Extensions
- Cookies and login sessions
- Autofill data

**Note:** Use the Chrome window launched by WhisprMute for Google Meet calls. Your regular Chrome can still run separately. If Chrome isn't in debug mode, WhisprMute will fall back to AppleScript (which briefly steals focus but restores it automatically).

### Required Permissions

WhisprMute needs several permissions to function. Open Settings > Permissions to see status and grant access:

- **Accessibility**: Required to control mute buttons in meeting apps
- **Automation**: Required to send commands to meeting apps
- **Camera**: Required for Chrome debug mode (Google Meet video calls)
- **Microphone**: Required for Chrome debug mode (Google Meet audio)

The Settings > Permissions tab shows which permissions are granted (green checkmark) or missing (orange warning), with buttons to request each permission.

## Usage

1. Launch WhisprMute - it appears in your menu bar
2. Join a Discord voice channel
3. Start dictating with Wispr Flow
4. WhisprMute automatically mutes you in Discord
5. When dictation stops, you're automatically unmuted

Your teammates never hear your dictation. You stay productive.

## How It Works

1. **Real-time Log Monitoring**: Uses `log stream` to monitor macOS system logs from `com.apple.coremedia` subsystem for Wispr Flow recording state changes - provides instant detection with no polling delay

2. **Discord RPC Integration**: Connects to Discord's local IPC socket and uses the RPC API with OAuth2 authentication to control mute state - no keyboard shortcuts or focus stealing

3. **Google Meet via Chrome DevTools Protocol**: Connects to Chrome's debug port (localhost:9222), finds the Meet tab via WebSocket, and injects JavaScript to click the mute button - no focus stealing required

4. **Smart State Management**: Remembers which apps were already muted before Wispr Flow started, and only unmutes apps that were previously unmuted

## Architecture

```
WhisprMute/
├── App/
│   ├── WhisprMuteApp.swift       # Main app entry
│   └── AppDelegate.swift         # Menu bar setup & coordination
├── Core/
│   ├── AudioLogMonitor.swift     # Real-time log stream monitoring
│   ├── WisprFlowDetector.swift   # Wispr Flow activity detection
│   ├── MeetingAppController.swift # Mute/unmute orchestration
│   ├── DiscordRPC.swift          # Discord RPC client with OAuth2
│   ├── CDPClient.swift           # Chrome DevTools Protocol client
│   └── ChromeDebugHelper.swift   # Chrome debug mode management
├── MeetingApps/
│   ├── MeetingApp.swift          # Protocol & base implementation
│   ├── DiscordController.swift   # Discord via RPC API
│   ├── GoogleMeetController.swift # Google Meet via CDP
│   └── ...                       # Other app controllers
└── UI/
    ├── MenuBarView.swift         # Menu bar icon and menu
    └── SettingsView.swift        # Settings window
```

## Troubleshooting

### Discord not muting

1. Ensure you've set up `~/.whisprmute` with your Discord credentials
2. Check that you've added `http://localhost` as a redirect URI in Discord Developer Portal
3. Delete `~/.whisprmute_token` to force re-authorization
4. Make sure you're in a voice channel when testing

### Google Meet not muting

1. **Check Chrome debug mode**: Open WhisprMute Settings > Permissions and check if "Chrome Debug Mode" shows a green checkmark
2. **Setup debug profile**: Click "Setup Debug Mode" in Settings > Permissions to create the debug Chrome profile
3. **Use the right Chrome**: Make sure you're using the Chrome window launched by WhisprMute, not your regular Chrome
4. **Verify manually**: Open `http://localhost:9222/json` in the debug Chrome - you should see JSON listing your tabs
5. **Check the Meet tab**: Make sure you're in an active Google Meet call (not just on the Meet homepage)
6. **Grant permissions**: Ensure Camera and Microphone permissions are granted (green checkmarks in Settings > Permissions)
7. **Fallback mode**: If Chrome isn't in debug mode, WhisprMute will use AppleScript which briefly steals focus - this is expected behavior

### Wispr Flow not detected

1. Make sure Wispr Flow is running
2. WhisprMute uses real-time log streaming - check Console.app for `com.apple.coremedia` logs mentioning "Wispr Flow"

## License

MIT License - see LICENSE file for details.

## Contributing

Contributions are welcome! We're especially looking for help with:
- Zoom integration
- Slack Huddles integration
- Microsoft Teams integration
- Other meeting app support

Please feel free to submit a Pull Request.
