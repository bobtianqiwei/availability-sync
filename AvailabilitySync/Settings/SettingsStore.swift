// SettingsStore.swift developed by Bob Tianqi Wei

import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let targetCalendarIdentifier = "targetCalendarIdentifier"
        static let calendarRules = "calendarRules"
        static let rangeMonths = "rangeMonths"
        static let syncIntervalMinutes = "syncIntervalMinutes"
        static let mergeDuplicates = "mergeDuplicates"
        static let launchAtLogin = "launchAtLogin"
        static let lastSyncDate = "lastSyncDate"
        static let managedTargetCalendarIdentifiers = "managedTargetCalendarIdentifiers"
    }

    private let defaults: UserDefaults

    @Published var targetCalendarIdentifier: String {
        didSet { defaults.set(targetCalendarIdentifier, forKey: Key.targetCalendarIdentifier) }
    }

    @Published private(set) var calendarRules: [String: CalendarMode] {
        didSet { saveCalendarRules() }
    }

    @Published var rangeMonths: Int {
        didSet { defaults.set(rangeMonths, forKey: Key.rangeMonths) }
    }

    @Published var syncIntervalMinutes: Int {
        didSet { defaults.set(syncIntervalMinutes, forKey: Key.syncIntervalMinutes) }
    }

    @Published var mergeDuplicates: Bool {
        didSet { defaults.set(mergeDuplicates, forKey: Key.mergeDuplicates) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    @Published var lastSyncDate: Date? {
        didSet { defaults.set(lastSyncDate, forKey: Key.lastSyncDate) }
    }

    @Published private(set) var managedTargetCalendarIdentifiers: Set<String> {
        didSet {
            defaults.set(Array(managedTargetCalendarIdentifiers), forKey: Key.managedTargetCalendarIdentifiers)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        targetCalendarIdentifier = defaults.string(forKey: Key.targetCalendarIdentifier) ?? ""

        if let data = defaults.data(forKey: Key.calendarRules),
           let decoded = try? JSONDecoder().decode([String: CalendarMode].self, from: data) {
            calendarRules = decoded
        } else {
            calendarRules = [:]
        }

        let savedRange = defaults.integer(forKey: Key.rangeMonths)
        rangeMonths = [1, 2, 4, 6, 12].contains(savedRange) ? savedRange : 4

        let savedInterval = defaults.integer(forKey: Key.syncIntervalMinutes)
        syncIntervalMinutes = [15, 30, 60].contains(savedInterval) ? savedInterval : 15

        if defaults.object(forKey: Key.mergeDuplicates) == nil {
            mergeDuplicates = true
        } else {
            mergeDuplicates = defaults.bool(forKey: Key.mergeDuplicates)
        }

        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        lastSyncDate = defaults.object(forKey: Key.lastSyncDate) as? Date
        managedTargetCalendarIdentifiers = Set(
            defaults.stringArray(forKey: Key.managedTargetCalendarIdentifiers) ?? []
        )
    }

    func mode(for calendarIdentifier: String) -> CalendarMode {
        calendarRules[calendarIdentifier] ?? .busyOnly
    }

    func setMode(_ mode: CalendarMode, for calendarIdentifier: String) {
        calendarRules[calendarIdentifier] = mode
    }

    func registerCurrentTarget() {
        guard !targetCalendarIdentifier.isEmpty else { return }
        managedTargetCalendarIdentifiers.insert(targetCalendarIdentifier)
    }

    func syncSettings() -> SyncSettings {
        SyncSettings(
            targetCalendarIdentifier: targetCalendarIdentifier,
            calendarModes: calendarRules,
            rangeMonths: rangeMonths,
            mergeDuplicates: mergeDuplicates,
            managedTargetCalendarIdentifiers: managedTargetCalendarIdentifiers.union([targetCalendarIdentifier])
        )
    }

    private func saveCalendarRules() {
        guard let data = try? JSONEncoder().encode(calendarRules) else { return }
        defaults.set(data, forKey: Key.calendarRules)
    }
}
