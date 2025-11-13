# Claude Code Context: Progress Bar DJ

## Project Overview

**Product:** Progress Bar DJ - A whimsical macOS menu bar app that plays "Girl from Ipanema" (or any user-selected song from Apple Music) whenever a progress bar appears system-wide.

**Full PRD:** See `progress-bar-dj-prd.md` for complete product requirements, features, and development roadmap.

**Tech Stack:**
- macOS 13.0+ (Ventura and later)
- Swift 5.9+
- SwiftUI for preferences UI
- AppKit for menu bar interface
- Accessibility API for progress bar detection
- MusicKit for Apple Music integration

---

## Critical Project Context

### Core Technical Challenge
The app's primary technical challenge is **reliable system-wide progress bar detection** using macOS Accessibility APIs. This is non-trivial because:
- Progress bars are implemented inconsistently across apps
- Need to filter false positives (loading spinners, indeterminate indicators)
- Must be performant (can't poll constantly)
- Requires proper permission handling

### Key Dependencies
1. **Accessibility API** - System-wide UI element observation
2. **MusicKit** - Requires Apple Developer account, MusicKit identifier, and proper entitlements
3. **Sandboxing considerations** - May need to distribute outside Mac App Store for full Accessibility access

---

## Xcode Project Setup

### Project Structure
```
ProgressBarDJ/
├── ProgressBarDJ/
│   ├── App/
│   │   ├── ProgressBarDJApp.swift          # Main app entry point
│   │   ├── AppDelegate.swift               # Menu bar setup, lifecycle
│   │   └── Info.plist                      # Permissions, bundle config
│   ├── Core/
│   │   ├── ProgressBarMonitor.swift        # Accessibility API logic
│   │   ├── PlaybackController.swift        # MusicKit integration
│   │   ├── SettingsManager.swift           # UserDefaults persistence
│   │   └── Models.swift                    # Data models
│   ├── UI/
│   │   ├── MenuBarView.swift               # Menu bar interface
│   │   ├── PreferencesWindow.swift         # Settings window
│   │   └── Components/                     # Reusable UI components
│   ├── Utilities/
│   │   ├── AccessibilityHelper.swift       # Permission checking
│   │   ├── Extensions.swift                # Swift extensions
│   │   └── Logger.swift                    # Logging utility
│   └── Resources/
│       ├── Assets.xcassets                 # Icons, images
│       └── Localizable.strings             # Localization
├── ProgressBarDJTests/                     # Unit tests
└── ProgressBarDJUITests/                   # UI tests
```

### Required Entitlements
```xml
<!-- ProgressBarDJ.entitlements -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>  <!-- May need to disable for Accessibility API -->
    <key>com.apple.security.device.audio-input</key>
    <false/>
    <key>com.apple.security.network.client</key>
    <true/>  <!-- For MusicKit API calls -->
</dict>
</plist>
```

### Info.plist Keys
```xml
<key>NSAppleMusicUsageDescription</key>
<string>Progress Bar DJ needs access to Apple Music to play your selected songs when progress bars appear.</string>

<key>NSAccessibilityUsageDescription</key>
<string>Progress Bar DJ needs Accessibility access to detect progress bars system-wide.</string>

<key>LSUIElement</key>
<true/>  <!-- Menu bar only app, no dock icon -->

<key>LSMinimumSystemVersion</key>
<string>13.0</string>
```

---

## Xcode Best Practices

### 1. Project Configuration
- **Always use** Swift Package Manager for dependencies (avoid CocoaPods)
- **Set deployment target** to macOS 13.0 explicitly
- **Enable Build Settings:**
  - Swift Strict Concurrency Checking: Complete
  - Debug Information Format: DWARF with dSYM (Release)
  - Optimization Level: Optimize for Speed (Release)
- **Code Signing:** Set up proper development team and certificates early

### 2. Build Schemes
Create multiple schemes for different development stages:
- **Debug** - Full logging, relaxed security
- **Testing** - Mock Accessibility API, test data
- **Release** - Optimizations, minimal logging
- **Distribution** - Notarization-ready

### 3. Working with SwiftUI + AppKit
This project uses **both** SwiftUI and AppKit:
- **AppKit** for menu bar (NSStatusItem) - required for menu bar apps
- **SwiftUI** for preferences window - modern, easier to build
- Use `NSHostingController` to bridge SwiftUI views into AppKit windows

Example:
```swift
// AppKit menu bar setup
class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "Progress Bar DJ")
    }
}

// SwiftUI preferences window
struct PreferencesWindow: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            AdvancedTab()
                .tabItem { Label("Advanced", systemImage: "slider.horizontal.3") }
        }
        .frame(width: 500, height: 400)
    }
}
```

### 4. Accessibility API Best Practices

**DO:**
- Request permissions early with clear explanations
- Use observer pattern (`AXObserverCreate`) rather than polling
- Filter by `AXRole` = `AXProgressIndicator`
- Implement debouncing (100-300ms) to avoid duplicate triggers
- Cache accessibility elements to reduce API calls
- Always run Accessibility code on background thread

**DON'T:**
- Poll accessibility tree continuously (kills performance)
- Assume all progress bars have same structure
- Ignore permission status (always check before using)
- Block main thread with accessibility operations

Example skeleton:
```swift
import ApplicationServices

class ProgressBarMonitor {
    private var observer: AXObserver?
    private var monitoredApps: Set<pid_t> = []
    
    func startMonitoring() {
        // Check permission first
        guard AXIsProcessTrusted() else {
            requestAccessibilityPermission()
            return
        }
        
        // Monitor running applications
        let workspace = NSWorkspace.shared
        workspace.notificationCenter.addObserver(
            self,
            selector: #selector(appLaunched),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )
    }
    
    @objc private func appLaunched(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
        monitorApp(pid: app.processIdentifier)
    }
    
    private func monitorApp(pid: pid_t) {
        // Create observer for this app
        var observer: AXObserver?
        let error = AXObserverCreate(pid, { observer, element, notification, refcon in
            // Handle progress bar appearance
            let monitor = Unmanaged<ProgressBarMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleProgressBar(element: element)
        }, &observer)
        
        guard error == .success, let observer = observer else { return }
        
        // Register for notifications
        AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), kAXCreatedNotification as CFString, Unmanaged.passUnretained(self).toOpaque())
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(observer), .defaultMode)
        self.observer = observer
    }
    
    private func handleProgressBar(element: AXUIElement) {
        // Verify it's actually a progress indicator
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        
        guard let roleString = role as? String, roleString == "AXProgressIndicator" else { return }
        
        // Trigger music playback
        NotificationCenter.default.post(name: .progressBarDetected, object: nil)
    }
}
```

### 5. MusicKit Integration

**Setup Requirements:**
1. Apple Developer account with MusicKit enabled
2. MusicKit identifier in App Capabilities
3. User must have active Apple Music subscription

**Implementation Notes:**
- Always check authorization status before playback
- Handle subscription errors gracefully
- Use `MusicPlayer.shared` for playback control
- Search for songs using `MusicCatalogSearchRequest`
- Store MusicKit tokens in Keychain (never UserDefaults)

Example:
```swift
import MusicKit

class PlaybackController: ObservableObject {
    @Published var isPlaying = false
    
    func requestAuthorization() async -> Bool {
        let status = await MusicAuthorization.request()
        return status == .authorized
    }
    
    func playDefaultSong() async {
        // Search for "Girl from Ipanema"
        var request = MusicCatalogSearchRequest(term: "Girl from Ipanema Stan Getz", types: [Song.self])
        request.limit = 1
        
        do {
            let response = try await request.response()
            guard let song = response.songs.first else { return }
            
            // Play the song
            let player = ApplicationMusicPlayer.shared
            player.queue = [song]
            try await player.play()
            
            isPlaying = true
        } catch {
            print("Playback error: \(error)")
        }
    }
    
    func fadeOut(duration: TimeInterval = 3.0) async {
        let player = ApplicationMusicPlayer.shared
        let startVolume = player.state.volume
        let steps = 30
        let stepDuration = duration / Double(steps)
        
        for i in 0..<steps {
            let volume = startVolume * (1.0 - Float(i) / Float(steps))
            // Note: Volume control may be limited in MusicKit
            try? await Task.sleep(nanoseconds: UInt64(stepDuration * 1_000_000_000))
        }
        
        player.stop()
        isPlaying = false
    }
}
```

---

## Code Style Guidelines

### Swift Conventions
- Use **Swift Concurrency** (async/await) over completion handlers
- Prefer **value types** (struct) over reference types (class) when appropriate
- Use **property wrappers**: `@Published`, `@AppStorage`, `@State`
- Follow **SOLID principles**, especially Single Responsibility
- Use **extensions** to organize code by functionality
- Add **documentation comments** (`///`) for public APIs

### Naming Conventions
- Classes: `PascalCase` (e.g., `ProgressBarMonitor`)
- Functions: `camelCase` (e.g., `handleProgressBar`)
- Constants: `camelCase` (e.g., `defaultSongTitle`)
- Enums: `PascalCase` with `camelCase` cases
- Protocols: `PascalCase`, often ending in "Protocol" or "Delegate"

### Error Handling
Always use Swift's typed error handling:
```swift
enum ProgressBarDJError: LocalizedError {
    case accessibilityNotAuthorized
    case appleMusicNotAuthorized
    case songNotFound
    case playbackFailed(underlying: Error)
    
    var errorDescription: String? {
        switch self {
        case .accessibilityNotAuthorized:
            return "Please enable Accessibility access in System Settings"
        case .appleMusicNotAuthorized:
            return "Please authorize Apple Music access"
        case .songNotFound:
            return "Could not find the selected song"
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        }
    }
}
```

---

## Testing Strategy

### Unit Tests
Focus on:
- Settings persistence (UserDefaults)
- Debouncing logic
- Edge case handling (multiple progress bars)
- State management

### Integration Tests
Test:
- Accessibility API permission flow (mock)
- MusicKit authorization flow (mock)
- Complete user flow from detection to playback

### Manual Testing Checklist
- [ ] Test with Finder file copy (reliable progress bar)
- [ ] Test with Safari download
- [ ] Test with Xcode build/compile
- [ ] Test with Final Cut export (long duration)
- [ ] Test with terminal commands (`dd`, `rsync`)
- [ ] Test rapid consecutive progress bars
- [ ] Test with Apple Music not installed
- [ ] Test with no Apple Music subscription
- [ ] Test with selected song unavailable

---

## Common Pitfalls & Solutions

### 1. Accessibility API Not Working
**Problem:** Progress bars not detected even with permissions
**Solution:** 
- Verify `AXIsProcessTrusted()` returns true
- Check System Settings > Privacy & Security > Accessibility
- Reset accessibility database: `tccutil reset Accessibility`
- Try monitoring specific apps first before system-wide

### 2. MusicKit Playback Issues
**Problem:** Songs won't play or authorization fails
**Solution:**
- Verify MusicKit capability in Xcode
- Check network connectivity
- Ensure user has active Apple Music subscription
- Use `.request()` not `.currentStatus` for authorization

### 3. Memory Leaks with Observers
**Problem:** App memory grows over time
**Solution:**
- Remove observers in `deinit`
- Use `weak self` in closures
- Properly clean up AXObserver objects
- Use Instruments to profile memory usage

### 4. App Not Appearing in Menu Bar
**Problem:** App launches but no menu bar icon
**Solution:**
- Verify `LSUIElement` is set to `true` in Info.plist
- Check status item is stored in persistent property (not local variable)
- Ensure `applicationDidFinishLaunching` is called

### 5. Build Fails with Code Signing
**Problem:** "Signing for [target] requires a development team"
**Solution:**
- Set development team in project settings
- Create free Apple Developer account if needed
- For distribution, use paid developer account
- Check certificate validity in Keychain Access

---

## Development Workflow

### Phase 1: Progress Bar Detection POC
1. Create minimal Xcode project (menu bar app template)
2. Request Accessibility permissions
3. Implement basic observer for progress indicators
4. Log all detected progress bars to console
5. Test with Finder file copy

**Success Criteria:** Console shows progress bar detections

### Phase 2: MusicKit Integration
1. Set up MusicKit in developer portal
2. Add MusicKit capability to Xcode project
3. Implement authorization flow
4. Hardcode "Girl from Ipanema" search and playback
5. Test playback manually (button trigger)

**Success Criteria:** Can play song on demand

### Phase 3: Connect Detection to Playback
1. Wire progress bar detection to playback trigger
2. Implement debouncing logic
3. Add fade in/out
4. Handle edge cases (already playing, multiple bars)

**Success Criteria:** Song plays automatically when progress bar appears

### Phase 4: UI Polish
1. Create preferences window (SwiftUI)
2. Implement settings persistence
3. Add menu bar controls
4. Design app icon

**Success Criteria:** Fully functional user-facing app

### Phase 5: Testing & Distribution
1. Comprehensive testing on different macOS versions
2. Code signing setup
3. Notarization process
4. Create DMG installer or .pkg

**Success Criteria:** Distributable app that passes Gatekeeper

---

## Debugging Tips

### Accessibility API Debugging
```swift
// Enable verbose logging
let app = AXUIElementCreateApplication(pid)
print("App element: \(app)")

var roleValue: CFTypeRef?
AXUIElementCopyAttributeValue(app, kAXRoleAttribute as CFString, &roleValue)
print("Role: \(roleValue ?? "nil")")

// List all attributes
var attributeNames: CFArray?
AXUIElementCopyAttributeNames(app, &attributeNames)
if let names = attributeNames as? [String] {
    print("Available attributes: \(names)")
}
```

### MusicKit Debugging
```swift
// Check authorization status
let status = MusicAuthorization.currentStatus
print("MusicKit status: \(status)")

// Check subscription
let subscription = MusicSubscription.current
print("Has subscription: \(subscription != nil)")

// Log search results
let request = MusicCatalogSearchRequest(term: "Girl from Ipanema", types: [Song.self])
let response = try await request.response()
print("Found \(response.songs.count) songs")
response.songs.forEach { print("  - \($0.title) by \($0.artistName)") }
```

### Performance Profiling
Use Instruments:
- **Time Profiler** - Check CPU usage (should be <2%)
- **Allocations** - Track memory leaks
- **System Trace** - Monitor system-wide impact
- **Energy Log** - Check battery impact

---

## Quick Reference

### Useful Commands
```bash
# Reset accessibility database
tccutil reset Accessibility

# Check if app is trusted
spctl --assess --verbose /path/to/ProgressBarDJ.app

# Sign app for distribution
codesign --force --sign "Developer ID Application: Your Name" --deep /path/to/ProgressBarDJ.app

# Create DMG
hdiutil create -volname "Progress Bar DJ" -srcfolder /path/to/app -ov -format UDZO ProgressBarDJ.dmg

# Notarize app (after uploading)
xcrun notarytool submit ProgressBarDJ.dmg --apple-id your@email.com --team-id TEAMID --wait

# Staple notarization ticket
xcrun stapler staple ProgressBarDJ.app
```

### Key Documentation Links
- [Accessibility API Reference](https://developer.apple.com/documentation/applicationservices/axuielement)
- [MusicKit Documentation](https://developer.apple.com/documentation/musickit/)
- [App Sandboxing Guide](https://developer.apple.com/documentation/security/app_sandbox)
- [Notarization Guide](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

---

## Communication Guidelines for Claude Code

When working on this project:

1. **Always reference the PRD** (`progress-bar-dj-prd.md`) for product decisions
2. **Ask for clarification** on UX/design choices before implementing
3. **Propose architectural decisions** before writing large amounts of code
4. **Surface technical risks** early (Accessibility API limitations, MusicKit issues)
5. **Provide testing instructions** with every significant change
6. **Document assumptions** when specs are ambiguous
7. **Suggest improvements** to user experience or implementation approach

Remember: This is a whimsical, delightful product. Code should be clean and professional, but the user experience should feel playful and fun.

---

**Last Updated:** November 13, 2025  
**Project Status:** Pre-development / Planning Phase
