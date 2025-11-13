//
//  MenuBarView.swift
//  ProgressBarDJ
//
//  Created on November 13, 2025.
//

import SwiftUI

/// Menu bar view for Progress Bar DJ
/// Currently minimal - will be expanded in future sprints
struct MenuBarView: View {
    var body: some View {
        VStack {
            Text("Progress Bar DJ")
                .font(.headline)
            Text("Menu bar app active")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

#Preview {
    MenuBarView()
}
