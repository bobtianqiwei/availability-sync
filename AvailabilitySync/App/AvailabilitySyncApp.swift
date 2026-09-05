// AvailabilitySyncApp.swift developed by Bob Tianqi Wei

import SwiftUI

@main
struct AvailabilitySyncApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Availability Sync", id: "main") {
            ContentView(model: model, settings: model.settings)
                .frame(minWidth: 560, minHeight: 620)
        }
        .defaultSize(width: 600, height: 720)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Sync Now") {
                    Task { await model.syncNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!model.canSync)
            }
        }

        MenuBarExtra(isInserted: Binding(
            get: { model.settings.showMenuBarIcon },
            set: { model.settings.showMenuBarIcon = $0 }
        )) {
            MenuBarView(model: model, settings: model.settings)
        } label: {
            Image("NavbarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
