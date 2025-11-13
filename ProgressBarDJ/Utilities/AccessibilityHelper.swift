//
//  AccessibilityHelper.swift
//  ProgressBarDJ
//
//  Created on November 13, 2025.
//

import Cocoa
import ApplicationServices

/// Helper class for managing Accessibility API permissions
class AccessibilityHelper {

    /// Check if the app has Accessibility permissions
    /// - Returns: true if permission is granted, false otherwise
    static func checkPermission() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request Accessibility permission with a prompt
    /// This will trigger the system permission dialog
    static func requestPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings to the Accessibility privacy pane
    static func openSystemSettings() {
        // macOS 13+ uses x-apple.systempreferences URL scheme
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Verify permission and show alert if not granted
    /// - Returns: true if permission is granted, false otherwise
    static func verifyPermissionOrAlert() -> Bool {
        let hasPermission = checkPermission()

        if !hasPermission {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "Progress Bar DJ needs Accessibility access to detect progress bars system-wide.\n\nPlease enable it in:\nSystem Settings > Privacy & Security > Accessibility"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open System Settings")
                alert.addButton(withTitle: "Cancel")

                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    openSystemSettings()
                }
            }
        }

        return hasPermission
    }
}
