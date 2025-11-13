//
//  ProgressBarMonitor.swift
//  ProgressBarDJ
//
//  Created on November 13, 2025.
//

import Cocoa
import ApplicationServices

/// Core class for monitoring progress bars system-wide using Accessibility API
class ProgressBarMonitor {
    private var monitoredApps: [pid_t: AXObserver] = [:]
    private var workspaceObserver: NSObjectProtocol?
    private var detectedProgressBars: Set<String> = []
    private var debounceTimer: Timer?
    private var pollingTimer: Timer?

    // Debounce interval to avoid duplicate detections
    private let debounceInterval: TimeInterval = 0.3
    // Polling interval for active scanning (in seconds)
    private let pollingInterval: TimeInterval = 1.0

    init() {
        print("🎵 ProgressBarMonitor initialized")
    }

    deinit {
        stopMonitoring()
    }

    /// Start monitoring for progress bars
    func startMonitoring() {
        guard AccessibilityHelper.checkPermission() else {
            print("❌ Cannot start monitoring - no Accessibility permission")
            return
        }

        print("🚀 Starting progress bar monitoring...")

        // Monitor for new apps launching
        startWorkspaceObserver()

        // Monitor currently running apps
        monitorRunningApplications()

        // Start polling timer for active scanning
        startPollingTimer()
    }

    /// Stop monitoring
    func stopMonitoring() {
        print("🛑 Stopping progress bar monitoring...")

        // Remove workspace observer
        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }

        // Clean up all AX observers
        for (_, observer) in monitoredApps {
            CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )
        }
        monitoredApps.removeAll()

        debounceTimer?.invalidate()
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Private Methods

    private func startWorkspaceObserver() {
        let center = NSWorkspace.shared.notificationCenter

        // Observe app launches
        workspaceObserver = center.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            print("📱 App launched: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
            self?.monitorApplication(app)
        }
    }

    private func monitorRunningApplications() {
        let runningApps = NSWorkspace.shared.runningApplications

        print("📊 Found \(runningApps.count) running applications")

        for app in runningApps {
            // Skip system apps and self
            guard app.activationPolicy == .regular else { continue }
            monitorApplication(app)
        }
    }

    private func monitorApplication(_ app: NSRunningApplication) {
        let pid = app.processIdentifier

        // Skip if already monitoring
        guard monitoredApps[pid] == nil else { return }

        // Create observer for this app
        var observer: AXObserver?
        let error = AXObserverCreate(pid, axObserverCallback, &observer)

        guard error == .success, let observer = observer else {
            if error != .success {
                print("⚠️ Failed to create observer for \(app.localizedName ?? "Unknown"): \(error.rawValue)")
            }
            return
        }

        // Store self reference for callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let appElement = AXUIElementCreateApplication(pid)

        // Try to add notification for UI element creation
        let addError = AXObserverAddNotification(
            observer,
            appElement,
            kAXCreatedNotification as CFString,
            selfPtr
        )

        if addError == .success {
            // Add observer to run loop
            CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                AXObserverGetRunLoopSource(observer),
                .defaultMode
            )

            monitoredApps[pid] = observer
            print("✅ Monitoring: \(app.localizedName ?? "Unknown") (PID: \(pid))")
        } else {
            print("⚠️ Failed to add notification for \(app.localizedName ?? "Unknown"): \(addError.rawValue)")
        }
    }

    fileprivate func handleUIElementCreated(element: AXUIElement) {
        // Check if this is a progress indicator
        var role: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        guard error == .success,
              let roleString = role as? String else {
            print("🔍 DEBUG: Failed to get role or no role string")
            return
        }

        // DEBUG: Log all roles we see
        print("🔍 DEBUG: UI Element Role: \(roleString)")

        // Check if it's a progress indicator
        if roleString == "AXProgressIndicator" || roleString == kAXProgressIndicatorRole as String {
            handleProgressBarDetected(element: element, role: roleString)
        }
    }

    private func handleProgressBarDetected(element: AXUIElement, role: String) {
        // Extract additional information about the progress bar
        var value: CFTypeRef?
        var minValue: CFTypeRef?
        var maxValue: CFTypeRef?
        var description: CFTypeRef?

        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        AXUIElementCopyAttributeValue(element, kAXMinValueAttribute as CFString, &minValue)
        AXUIElementCopyAttributeValue(element, kAXMaxValueAttribute as CFString, &maxValue)
        AXUIElementCopyAttributeValue(element, kAXDescriptionAttribute as CFString, &description)

        // Get the parent application
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? "Unknown"

        // Create a unique identifier for this progress bar
        let valueStr = value.map { "\($0)" } ?? "nil"
        let identifier = "\(pid)-\(role)-\(valueStr)"

        // Debounce: only log if we haven't seen this recently
        if !detectedProgressBars.contains(identifier) {
            detectedProgressBars.insert(identifier)

            // Log detection with details
            let minStr = minValue.map { "\($0)" } ?? "nil"
            let maxStr = maxValue.map { "\($0)" } ?? "nil"
            let descStr = description.map { "\($0)" } ?? "nil"

            print("""

            🎉 PROGRESS BAR DETECTED!
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            App:         \(appName)
            PID:         \(pid)
            Role:        \(role)
            Value:       \(valueStr)
            Min:         \(minStr)
            Max:         \(maxStr)
            Description: \(descStr)
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            """)

            // Set timer to remove from detected set (debouncing)
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
                self?.detectedProgressBars.remove(identifier)
            }
        }
    }

    // MARK: - Polling-based Detection

    private func startPollingTimer() {
        print("⏱️ Starting polling timer (checking every \(pollingInterval)s)")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { [weak self] _ in
            self?.pollForProgressBars()
        }
    }

    private func pollForProgressBars() {
        // Get the frontmost application
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

        let pid = frontApp.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)

        // Search for progress indicators in the frontmost app
        searchForProgressBars(in: appElement, appName: frontApp.localizedName ?? "Unknown", pid: pid)
    }

    private func searchForProgressBars(in element: AXUIElement, appName: String, pid: pid_t) {
        // Get the role of this element
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)

        if let roleString = role as? String {
            // Check if this is a progress indicator
            if roleString == "AXProgressIndicator" || roleString == kAXProgressIndicatorRole as String {
                print("🔍 POLLING: Found progress indicator in \(appName)!")
                handleProgressBarDetected(element: element, role: roleString)
                return
            }
        }

        // Recursively search children
        var childrenRef: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)

        guard error == .success, let children = childrenRef as? [AXUIElement] else {
            return
        }

        // Limit depth to avoid performance issues (only search first few levels)
        if children.count > 100 {
            return // Too many children, skip to avoid slowdown
        }

        for child in children {
            searchForProgressBars(in: child, appName: appName, pid: pid)
        }
    }
}

// MARK: - Accessibility Observer Callback

private func axObserverCallback(
    observer: AXObserver,
    element: AXUIElement,
    notification: CFString,
    refcon: UnsafeMutableRawPointer?
) -> Void {
    guard let refcon = refcon else { return }

    let monitor = Unmanaged<ProgressBarMonitor>.fromOpaque(refcon).takeUnretainedValue()

    // DEBUG: Log all notifications received
    let notificationName = notification as String
    var pid: pid_t = 0
    AXUIElementGetPid(element, &pid)
    let app = NSRunningApplication(processIdentifier: pid)
    print("🔍 DEBUG: Notification '\(notificationName)' from \(app?.localizedName ?? "Unknown")")

    // Handle the notification on main thread
    DispatchQueue.main.async {
        monitor.handleUIElementCreated(element: element)
    }
}
