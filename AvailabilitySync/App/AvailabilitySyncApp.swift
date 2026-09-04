// AvailabilitySyncApp.swift developed by Bob Tianqi Wei

import SwiftUI

@main
struct AvailabilitySyncApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model, settings: model.settings)
                .frame(minWidth: 680, minHeight: 620)
        }
        .defaultSize(width: 760, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Sync Now") {
                    Task { await model.syncNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!model.canSync)
            }
        }
    }
}
