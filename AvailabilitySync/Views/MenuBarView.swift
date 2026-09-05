// MenuBarView.swift developed by Bob Tianqi Wei

import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Text(lastSyncText)

        Divider()

        Button {
            Task { await model.syncNow() }
        } label: {
            Label(syncButtonTitle, systemImage: "arrow.triangle.2.circlepath")
        }
        .disabled(!model.canSync)

        Button {
            openWindow(id: "main")
            NSApplication.shared.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Availability Sync", systemImage: "macwindow")
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }

    private var lastSyncText: String {
        guard let date = settings.lastSyncDate else {
            return "Last Sync: Never"
        }
        return "Last Sync: \(date.formatted(date: .abbreviated, time: .shortened))"
    }

    private var syncButtonTitle: String {
        model.syncState == .syncing ? "Syncing…" : "Sync Now"
    }
}
