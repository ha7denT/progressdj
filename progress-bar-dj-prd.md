# Product Requirements Document: Progress Bar DJ

## 1. Product Overview

**Product Name:** Progress Bar DJ (working title)

**Tagline:** "Every wait deserves a soundtrack"

**Vision:** A macOS menu bar app that transforms mundane progress bars into delightful moments by automatically playing "Girl from Ipanema" (or any user-selected song) whenever a progress bar appears anywhere on the system.

**Target Audience:** 
- Mac power users who enjoy whimsical productivity tools
- Creative professionals with frequent renders/exports
- Anyone who spends time waiting for file transfers, installations, or processing

## 2. Core User Flow

1. User downloads and installs app
2. App requests Accessibility permissions (to detect progress bars)
3. App requests MusicKit authorization (Apple Music access)
4. On first launch: defaults to "Girl from Ipanema" by Stan Getz & João Gilberto
5. When any progress bar spawns system-wide → music starts playing
6. When progress bar completes/disappears → music fades out
7. User can customize song selection via menu bar preferences

## 3. Key Features

### MVP (Version 1.0)

**Core Functionality:**
- System-wide progress bar detection
- Automatic music playback via Apple Music
- Default song: "Girl from Ipanema"
- Menu bar icon & controls
- Basic settings panel

**Settings:**
- Enable/disable the app
- Change default song (search Apple Music library)
- Volume control
- Fade in/out duration
- Minimum progress bar duration (avoid triggering on tiny 1-second bars)

**Menu Bar Controls:**
- Play/Pause current song
- Skip to next occurrence
- Disable for X minutes
- Open Preferences
- Quit

### Phase 2 Features (Future)

- Multiple song playlists (different songs for different scenarios)
- Smart detection: different songs for different apps (e.g., Final Cut renders vs. Finder copies)
- Progress percentage milestones (play different songs at 25%, 50%, 75%, 100%)
- Spotify integration
- Custom audio files support
- "Hall of Fame" stats (most progress bars triggered by app, total listening time)
- Social sharing: "I've listened to Girl from Ipanema 437 times thanks to Xcode"

## 4. Technical Requirements

### Platform
- macOS 13.0+ (Ventura and later)
- Apple Silicon & Intel support

### Required APIs & Frameworks
- **Accessibility API** - detect UI elements system-wide
- **MusicKit** - Apple Music integration
- **Cocoa/AppKit** - macOS app framework
- **UserNotifications** - optional notifications

### Permissions Required
- Accessibility Access (critical)
- Apple Music authorization (critical)
- Notifications (optional)

### Technical Constraints
- Must run with minimal CPU/memory footprint
- Should not interfere with system performance
- Must handle edge cases (multiple simultaneous progress bars)

## 5. UI/UX Specifications

### Menu Bar Icon
- Simple, minimal icon (progress bar graphic or music note)
- State indicators: active (colored), disabled (gray), playing (animated)

### Preferences Window

**General Tab:**
```
☑ Enable Progress Bar DJ
☐ Launch at login

Default Song: 🎵 Girl from Ipanema - Stan Getz & João Gilberto [Change]

Volume: [=========>---] 75%

Fade in duration: [2] seconds
Fade out duration: [3] seconds

☑ Only trigger for progress bars longer than [3] seconds

[Test Progress Bar] button
```

**Advanced Tab:**
```
☑ Show notification when song starts
☐ Pause other audio sources
☑ Resume previous playback after completion

Excluded Apps: [Add apps to ignore]
- Spotify
- Music
[+ Add]

Debug: 
☐ Log all progress bar detections
[View Logs]
```

**About Tab:**
```
Progress Bar DJ v1.0
Every wait deserves a soundtrack

[Check for Updates]
[Report an Issue]
[Buy Me a Coffee]
```

## 6. Technical Architecture

### Core Components

**1. Progress Bar Monitor**
```
- Uses Accessibility API to observe UI element changes
- Filters for AXProgressIndicator elements
- Tracks appearance, updates, and disappearance
- Debouncing logic to avoid false triggers
```

**2. Playback Controller**
```
- Interfaces with MusicKit
- Manages playback state
- Handles fade in/out
- Volume management
- Error handling (no subscription, song unavailable)
```

**3. Settings Manager**
```
- UserDefaults for preferences
- Keychain for MusicKit tokens
- State persistence
```

**4. Menu Bar Interface**
```
- NSStatusItem for menu bar presence
- Menu construction
- Preferences window management
```

### Data Flow
```
Progress Bar Detected → 
Check minimum duration → 
Check if app excluded → 
Check if already playing → 
Query MusicKit for song → 
Start playback with fade in → 
Monitor progress bar → 
On completion: fade out
```

## 7. Development Phases

### Phase 1: Proof of Concept (Week 1)
- [ ] Set up Xcode project
- [ ] Implement basic Accessibility API progress bar detection
- [ ] Log all detected progress bars to console
- [ ] Test with Finder file copies, Safari downloads

### Phase 2: MusicKit Integration (Week 1-2)
- [ ] Implement MusicKit authentication
- [ ] Search and playback functionality
- [ ] Hardcode "Girl from Ipanema" test
- [ ] Handle errors (no subscription, song not found)

### Phase 3: Core Logic (Week 2-3)
- [ ] Connect progress bar detection to playback
- [ ] Implement debouncing and filtering
- [ ] Add fade in/out
- [ ] Handle multiple simultaneous progress bars

### Phase 4: UI Development (Week 3-4)
- [ ] Menu bar icon and menu
- [ ] Preferences window design
- [ ] Settings persistence
- [ ] Song selection interface

### Phase 5: Polish & Testing (Week 4-5)
- [ ] Edge case handling
- [ ] Performance optimization
- [ ] User testing with real workflows
- [ ] App icon design
- [ ] Onboarding flow

### Phase 6: Distribution (Week 5-6)
- [ ] Code signing
- [ ] Notarization
- [ ] Website/landing page
- [ ] Distribution strategy (Mac App Store vs. direct)

## 8. Edge Cases & Error Handling

### Scenarios to Handle:
- No Apple Music subscription → Show helpful error, link to subscribe
- Selected song not in user's library → Fall back to search/prompt user
- Multiple progress bars simultaneously → Play once, extend duration
- Very short progress bars (<1 second) → Ignore via minimum duration setting
- Progress bar appears while song already playing → Don't interrupt
- macOS updates breaking Accessibility API → Graceful degradation
- Network issues with Apple Music → Cache/queue handling

## 9. Success Metrics

### User Engagement:
- Daily active users
- Average progress bars detected per user per day
- Retention (7-day, 30-day)

### Technical Performance:
- CPU usage <2%
- Memory footprint <50MB
- Crash rate <0.1%

### Viral Potential:
- Social media shares
- Word-of-mouth referrals
- Press coverage

## 10. Marketing & Distribution

### Value Proposition:
"Turn every boring progress bar into a moment of joy"

### Key Messaging:
- Whimsical productivity tool
- Makes waiting fun
- Highly customizable
- Respects your workflow

### Distribution:
- Direct download from website (primary)
- Product Hunt launch
- Mac App Store (consider limitations with Accessibility API)
- Reddit (r/macapps, r/productivity)
- Twitter/X tech community

### Pricing:
- **Option A:** Free with optional "tip jar"
- **Option B:** $4.99 one-time purchase
- **Option C:** Freemium (free for one song, $2.99 for unlimited customization)

## 11. Open Questions

- [ ] How to handle very long progress bars (hour-long renders)? Loop song or play playlist?
- [ ] Should we support local audio files or just streaming services?
- [ ] What's the ideal minimum progress bar duration threshold?
- [ ] Should we auto-pause if user manually opens Music app?
- [ ] Dark mode icon variants?

## 12. Technical Risks

**High Priority:**
- Accessibility API detection reliability across different apps
- Apple Music API rate limits
- Breaking changes in macOS updates

**Medium Priority:**
- Battery impact on laptops
- Performance with resource-intensive apps

**Low Priority:**
- Internationalization (progress bar UI elements in different languages)

---

## Next Steps

1. Set up development environment
2. Register Apple Developer account
3. Create MusicKit identifier and keys
4. Start Phase 1: Progress bar detection POC
5. Document findings and iterate

**Ready to start building?** Let's begin with the progress bar detection component.
