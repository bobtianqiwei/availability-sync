// AvailabilitySyncApp.swift developed by Bob Tianqi Wei

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let showsDockIcon = defaults.bool(forKey: "showDockIcon")
        NSApplication.shared.setActivationPolicy(showsDockIcon ? .regular : .accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AvailabilitySyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockIcon") private var showDockIcon = false

    var body: some Scene {
        Window("Availability Sync", id: "main") {
            ContentView(
                model: model,
                settings: model.settings,
                showMenuBarIcon: $showMenuBarIcon,
                showDockIcon: $showDockIcon
            )
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

        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(model: model, settings: model.settings)
        } label: {
            Image("NavbarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
