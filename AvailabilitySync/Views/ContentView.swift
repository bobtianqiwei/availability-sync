// ContentView.swift developed by Bob Tianqi Wei

import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Group {
            if model.eventKit.permissionStatus.canReadEvents {
                settingsContent
            } else {
                permissionContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            model.start()
        }
    }

    private var settingsContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                targetSection
                sourceSection
                scheduleSection
                syncFooter
            }
            .padding(24)
        }
    }

    private var targetSection: some View {
        SettingsSection(title: "Destination", systemImage: "arrow.down.to.line.compact") {
            HStack {
                Text("Target Calendar")
                Spacer()
                Picker("Target Calendar", selection: Binding(
                    get: { settings.targetCalendarIdentifier },
                    set: { model.setTargetCalendar($0) }
                )) {
                    Text("Choose a calendar…").tag("")
                    ForEach(model.writableCalendars) { calendar in
                        Label {
                            Text(calendar.displayName)
                        } icon: {
                            Image(systemName: "circle.fill")
                                .foregroundStyle(calendar.color)
                        }
                        .tag(calendar.id)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 380)
            }

            Text("Synced events are managed only in this calendar. Other events are left untouched.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var sourceSection: some View {
        SettingsSection(title: "Source Calendars", systemImage: "calendar") {
            if model.sourceCalendars.isEmpty {
                Text("No source calendars are available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.sourceCalendars.enumerated()), id: \.element.id) { index, calendar in
                        CalendarRuleRow(calendar: calendar, mode: Binding(
                            get: { settings.mode(for: calendar.id) },
                            set: { settings.setMode($0, for: calendar.id) }
                        ))
                        if index < model.sourceCalendars.count - 1 {
                            Divider().padding(.leading, 29)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .background(.background, in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.separator.opacity(0.55), lineWidth: 1)
                }
            }

            Text("New calendars default to Busy Only. The target calendar is always excluded.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scheduleSection: some View {
        SettingsSection(title: "Sync Settings", systemImage: "gearshape") {
            LabeledContent("Past range") {
                Picker("Past range", selection: $settings.pastRange) {
                    ForEach(PastRange.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            LabeledContent("Future range") {
                Picker("Future range", selection: $settings.rangeMonths) {
                    ForEach([1, 2, 4, 6, 12], id: \.self) { months in
                        Text("\(months) \(months == 1 ? "month" : "months")").tag(months)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            LabeledContent("Automatic sync") {
                Picker("Automatic sync", selection: $settings.syncIntervalMinutes) {
                    ForEach([1, 3, 5, 10, 15, 30, 60], id: \.self) { minutes in
                        Text("Every \(minutes) min").tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 140)
            }

            Toggle("Merge duplicate events", isOn: $settings.mergeDuplicates)
            Toggle("Show Menu Bar Icon", isOn: $settings.showMenuBarIcon)
            Toggle("Launch at Login", isOn: Binding(
                get: { settings.launchAtLogin },
                set: { model.setLaunchAtLogin($0) }
            ))
        }
    }

    private var syncFooter: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                if let lastSyncDate = settings.lastSyncDate {
                    Text("Last sync: \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline.weight(.medium))
                } else {
                    Text("Not synced yet")
                        .font(.subheadline.weight(.medium))
                }

                if let detail = model.syncState.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(model.syncState.isFailure ? .red : .secondary)
                } else {
                    Text("Automatic sync continues while the app is running.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
            Button {
                Task { await model.syncNow() }
            } label: {
                HStack(spacing: 7) {
                    if model.syncState == .syncing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(model.syncState == .syncing ? "Syncing…" : "Sync Now")
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!model.canSync)
        }
        .padding(.top, 2)
    }

    private var permissionContent: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(.secondary)
            Text("Calendar Access Required")
                .font(.title2.weight(.semibold))
            Text(permissionMessage)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 430)

            HStack {
                if model.eventKit.permissionStatus == .notDetermined {
                    Button("Grant Calendar Access") {
                        Task { await model.requestCalendarAccess() }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Open Privacy Settings") {
                        model.eventKit.openCalendarPrivacySettings()
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Check Again") {
                        model.eventKit.refreshCalendars()
                    }
                }
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var permissionMessage: String {
        switch model.eventKit.permissionStatus {
        case .notDetermined:
            "Availability Sync needs full Calendar access to read source events and update your chosen target calendar."
        case .writeOnly:
            "Write-only access cannot read source calendars. Allow Full Access in System Settings."
        case .denied, .restricted:
            "Allow Full Calendar Access in System Settings → Privacy & Security → Calendars."
        case .fullAccess:
            ""
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content
        }
    }
}

private struct CalendarRuleRow: View {
    let calendar: CalendarInfo
    @Binding var mode: CalendarMode

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(calendar.color)
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 1) {
                Text(calendar.title)
                    .lineLimit(1)
                Text(calendar.sourceTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Picker("Mode", selection: $mode) {
                ForEach(CalendarMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 250)
        }
        .padding(.vertical, 8)
    }
}

private extension CalendarInfo {
    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}

private extension SyncState {
    var isFailure: Bool {
        if case .failure = self { return true }
        return false
    }
}
