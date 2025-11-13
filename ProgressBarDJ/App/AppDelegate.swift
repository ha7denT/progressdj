//
//  AppDelegate.swift
//  ProgressBarDJ
//
//  Created on November 13, 2025.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var progressBarMonitor: ProgressBarMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            // Use SF Symbol for menu bar icon
            button.image = NSImage(systemSymbolName: "waveform.circle", accessibilityDescription: "Progress Bar DJ")
        }

        // Set up menu bar menu
        setupMenu()

        // Check accessibility permissions
        let hasPermission = AccessibilityHelper.checkPermission()

        if hasPermission {
            // Initialize and start monitoring
            progressBarMonitor = ProgressBarMonitor()
            progressBarMonitor?.startMonitoring()
            print("✅ Accessibility permission granted - monitoring started")
        } else {
            // Request permission
            print("⚠️ Accessibility permission required")
            AccessibilityHelper.requestPermission()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        progressBarMonitor?.stopMonitoring()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status item
        let statusMenuItem = NSMenuItem(title: "Monitoring: Waiting...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        menu.addItem(NSMenuItem.separator())

        // View Logs
        menu.addItem(NSMenuItem(title: "View Logs", action: #selector(viewLogs), keyEquivalent: "l"))

        // Check Permissions
        menu.addItem(NSMenuItem(title: "Check Permissions", action: #selector(checkPermissions), keyEquivalent: "p"))

        menu.addItem(NSMenuItem.separator())

        // Preferences (disabled for now)
        let prefsItem = NSMenuItem(title: "Preferences...", action: nil, keyEquivalent: ",")
        prefsItem.isEnabled = false
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        menu.addItem(NSMenuItem(title: "Quit Progress Bar DJ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc func viewLogs() {
        print("📋 View Logs clicked")
        // TODO: Implement logs window
        let alert = NSAlert()
        alert.messageText = "Logs"
        alert.informativeText = "Check Console.app for detailed logs.\nFilter by process: ProgressBarDJ"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc func checkPermissions() {
        let hasPermission = AccessibilityHelper.checkPermission()

        let alert = NSAlert()
        alert.messageText = "Accessibility Permission"

        if hasPermission {
            alert.informativeText = "✅ Accessibility permission is granted.\n\nProgress Bar DJ can monitor system-wide progress bars."
            alert.alertStyle = .informational
        } else {
            alert.informativeText = "⚠️ Accessibility permission is not granted.\n\nPlease enable it in:\nSystem Settings > Privacy & Security > Accessibility"
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
        }

        alert.addButton(withTitle: "OK")
        let response = alert.runModal()

        if response == .alertFirstButtonReturn && !hasPermission {
            AccessibilityHelper.openSystemSettings()
        }
    }
}
