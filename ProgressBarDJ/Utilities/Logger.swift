//
//  Logger.swift
//  ProgressBarDJ
//
//  Created on November 13, 2025.
//

import Foundation

class Logger {
    static let shared = Logger()
    private let logFilePath = "/tmp/progressbardj_debug.log"

    private init() {
        // Create/clear log file
        try? "=== ProgressBarDJ Debug Log ===\n".write(toFile: logFilePath, atomically: true, encoding: .utf8)
    }

    func log(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let logMessage = "[\(timestamp)] \(message)\n"

        // Also print to console
        print(message)

        // Write to file
        if let handle = FileHandle(forWritingAtPath: logFilePath) {
            handle.seekToEndOfFile()
            if let data = logMessage.data(using: .utf8) {
                handle.write(data)
            }
            handle.closeFile()
        }
    }
}
