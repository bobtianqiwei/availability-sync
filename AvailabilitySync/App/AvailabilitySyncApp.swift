// AvailabilitySyncApp.swift developed by Bob Tianqi Wei

import AppKit
import Sparkle
import SwiftUI

@MainActor
final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    init(updater: SPUUpdater) {
        updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
}

struct CheckForUpdatesView: View {
    @ObservedObject private var viewModel: CheckForUpdatesViewModel
    private let updater: SPUUpdater

    init(updater: SPUUpdater) {
        self.updater = updater
        viewModel = CheckForUpdatesViewModel(updater: updater)
    }

    var body: some View {
        Button("Check for Updates…", action: updater.checkForUpdates)
            .disabled(!viewModel.canCheckForUpdates)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let defaults = UserDefaults.standard
        let showsDockIcon = defaults.bool(forKey: "showDockIcon")
        NSApplication.shared.setActivationPolicy(showsDockIcon ? .regular : .accessory)
        model.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct AvailabilitySyncApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private var model: AppModel { appDelegate.model }
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockIcon") private var showDockIcon = false
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

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
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }

            CommandGroup(after: .newItem) {
                Button("Sync Now") {
                    Task { await model.syncNow() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!model.canSync)
            }
        }

        MenuBarExtra(isInserted: $showMenuBarIcon) {
            MenuBarView(
                model: model,
                settings: model.settings,
                updater: updaterController.updater
            )
        } label: {
            Image("NavbarIcon")
                .renderingMode(.template)
        }
        .menuBarExtraStyle(.menu)
    }
}
