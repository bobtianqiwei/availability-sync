// SettingsStore.swift developed by Bob Tianqi Wei

import Foundation
import Combine

protocol CloudSettingsStorage: AnyObject {
    func object(forKey key: String) -> Any?
    func set(_ value: Any?, forKey key: String)
    @discardableResult func synchronize() -> Bool
}

extension NSUbiquitousKeyValueStore: CloudSettingsStorage {}

@MainActor
final class SettingsStore: ObservableObject {
    private enum Key {
        static let targetCalendarIdentifier = "targetCalendarIdentifier"
        static let calendarRules = "calendarRules"
        static let bufferMinutes = "bufferMinutes"
        static let bufferEnabledCalendarIdentifiers = "bufferEnabledCalendarIdentifiers"
        static let pastRange = "pastRange"
        static let rangeMonths = "rangeMonths"
        static let syncIntervalMinutes = "syncIntervalMinutes"
        static let mergeDuplicates = "mergeDuplicates"
        static let allDayBlockedWords = "allDayBlockedWords"
        static let deleteEventsBeforeSyncRange = "deleteEventsBeforeSyncRange"
        static let launchAtLogin = "launchAtLogin"
        static let lastSyncDate = "lastSyncDate"
        static let managedTargetCalendarIdentifiers = "managedTargetCalendarIdentifiers"
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
    }

    private let defaults: UserDefaults
    @Published private(set) var calendarOrder: [String] {
        didSet { defaults.set(calendarOrder, forKey: "calendarOrder") }
    }
    @Published private(set) var sharedCalendarOrder: [String] {
        didSet { saveShared(sharedCalendarOrder, forKey: "sharedCalendarOrder") }
    }
    private let cloudStore: CloudSettingsStorage
    private var cloudObserver: AnyCancellable?
    private var applyingCloudSettings = false
    private static let cloudPrefix = "settings.v1."

    @Published var iCloudSyncEnabled: Bool {
        didSet {
            defaults.set(iCloudSyncEnabled, forKey: Key.iCloudSyncEnabled)
            if iCloudSyncEnabled { refreshCloudSettings() }
        }
    }

    @Published private(set) var iCloudStatus = "Settings sync is off."

    @Published var targetCalendarIdentifier: String {
        didSet { defaults.set(targetCalendarIdentifier, forKey: Key.targetCalendarIdentifier) }
    }

    @Published private(set) var calendarRules: [String: CalendarMode] {
        didSet { saveCalendarRules() }
    }

    @Published var pastRange: PastRange {
        didSet { saveShared(pastRange.rawValue, forKey: Key.pastRange) }
    }

    @Published var bufferMinutes: Int {
        didSet { saveShared(bufferMinutes, forKey: Key.bufferMinutes) }
    }

    @Published private(set) var bufferEnabledCalendarIdentifiers: Set<String> {
        didSet {
            defaults.set(
                Array(bufferEnabledCalendarIdentifiers),
                forKey: Key.bufferEnabledCalendarIdentifiers
            )
        }
    }

    @Published var rangeMonths: Int {
        didSet { saveShared(rangeMonths, forKey: Key.rangeMonths) }
    }

    @Published var syncIntervalMinutes: Int {
        didSet { saveShared(syncIntervalMinutes, forKey: Key.syncIntervalMinutes) }
    }

    @Published var mergeDuplicates: Bool {
        didSet { saveShared(mergeDuplicates, forKey: Key.mergeDuplicates) }
    }

    @Published var allDayBlockedWords: String {
        didSet { saveShared(allDayBlockedWords, forKey: Key.allDayBlockedWords) }
    }

    @Published var deleteEventsBeforeSyncRange: Bool {
        didSet {
            saveShared(
                deleteEventsBeforeSyncRange,
                forKey: Key.deleteEventsBeforeSyncRange
            )
        }
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

    init(defaults: UserDefaults = .standard, cloudStore: CloudSettingsStorage = NSUbiquitousKeyValueStore.default) {
        self.defaults = defaults
        calendarOrder = defaults.stringArray(forKey: "calendarOrder") ?? []
        sharedCalendarOrder = defaults.stringArray(forKey: "sharedCalendarOrder") ?? []
        self.cloudStore = cloudStore
        iCloudSyncEnabled = defaults.bool(forKey: Key.iCloudSyncEnabled)
        targetCalendarIdentifier = defaults.string(forKey: Key.targetCalendarIdentifier) ?? ""
        let savedBufferMinutes = defaults.integer(forKey: Key.bufferMinutes)
        bufferMinutes = [5, 10, 15, 30].contains(savedBufferMinutes) ? savedBufferMinutes : 15
        bufferEnabledCalendarIdentifiers = Set(
            defaults.stringArray(forKey: Key.bufferEnabledCalendarIdentifiers) ?? []
        )

        if let data = defaults.data(forKey: Key.calendarRules),
           let decoded = try? JSONDecoder().decode([String: CalendarMode].self, from: data) {
            calendarRules = decoded
        } else {
            calendarRules = [:]
        }

        pastRange = PastRange(rawValue: defaults.string(forKey: Key.pastRange) ?? "") ?? .oneWeek

        let savedRange = defaults.integer(forKey: Key.rangeMonths)
        rangeMonths = [1, 2, 4, 6, 12].contains(savedRange) ? savedRange : 4

        let savedInterval = defaults.integer(forKey: Key.syncIntervalMinutes)
        syncIntervalMinutes = [1, 3, 5, 10, 15, 30, 60].contains(savedInterval) ? savedInterval : 15

        if defaults.object(forKey: Key.mergeDuplicates) == nil {
            mergeDuplicates = true
        } else {
            mergeDuplicates = defaults.bool(forKey: Key.mergeDuplicates)
        }

        deleteEventsBeforeSyncRange = defaults.bool(forKey: Key.deleteEventsBeforeSyncRange)
        allDayBlockedWords = defaults.string(forKey: Key.allDayBlockedWords) ?? "birthday, 生日"

        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        lastSyncDate = defaults.object(forKey: Key.lastSyncDate) as? Date
        managedTargetCalendarIdentifiers = Set(
            defaults.stringArray(forKey: Key.managedTargetCalendarIdentifiers) ?? []
        )
        cloudObserver = NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloudStore
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] notification in
            guard let self, self.iCloudSyncEnabled else { return }
            let reason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int
            if reason == NSUbiquitousKeyValueStoreAccountChange {
                self.iCloudSyncEnabled = false
                self.iCloudStatus = "Apple Account changed. Enable sync again to use the current account."
            } else if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
                self.iCloudStatus = "iCloud storage limit reached. Settings are still saved on this Mac."
            } else {
                self.receiveCloudSettings()
            }
        }
        if iCloudSyncEnabled { refreshCloudSettings() }
    }

    private var sharedValues: [String: Any] {
        [
            "sharedCalendarOrder": sharedCalendarOrder,
            Key.pastRange: pastRange.rawValue,
            Key.rangeMonths: rangeMonths,
            Key.syncIntervalMinutes: syncIntervalMinutes,
            Key.bufferMinutes: bufferMinutes,
            Key.mergeDuplicates: mergeDuplicates,
            Key.allDayBlockedWords: allDayBlockedWords,
            Key.deleteEventsBeforeSyncRange: deleteEventsBeforeSyncRange
        ]
    }

    private func saveShared(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        guard iCloudSyncEnabled, !applyingCloudSettings else { return }
        cloudStore.set(value, forKey: Self.cloudPrefix + key)
    }

    private func refreshCloudSettings() {
        guard cloudStore.synchronize() else {
            iCloudStatus = "iCloud is unavailable. Settings are still saved on this Mac."
            return
        }
        receiveCloudSettings()
        for (key, value) in sharedValues where cloudStore.object(forKey: Self.cloudPrefix + key) == nil {
            cloudStore.set(value, forKey: Self.cloudPrefix + key)
        }
    }

    func receiveCloudSettings() {
        guard iCloudSyncEnabled else { return }
        applyingCloudSettings = true
        defer { applyingCloudSettings = false }
        func value(_ key: String) -> Any? { cloudStore.object(forKey: Self.cloudPrefix + key) }
        if let order = value("sharedCalendarOrder") as? [String] { sharedCalendarOrder = order }
        if let raw = value(Key.pastRange) as? String, let range = PastRange(rawValue: raw) { pastRange = range }
        if let months = value(Key.rangeMonths) as? Int, [1, 2, 4, 6, 12].contains(months) { rangeMonths = months }
        if let minutes = value(Key.syncIntervalMinutes) as? Int, [1, 3, 5, 10, 15, 30, 60].contains(minutes) { syncIntervalMinutes = minutes }
        if let minutes = value(Key.bufferMinutes) as? Int, [5, 10, 15, 30].contains(minutes) { bufferMinutes = minutes }
        if let merge = value(Key.mergeDuplicates) as? Bool { mergeDuplicates = merge }
        if let words = value(Key.allDayBlockedWords) as? String { allDayBlockedWords = words }
        if let delete = value(Key.deleteEventsBeforeSyncRange) as? Bool { deleteEventsBeforeSyncRange = delete }
        iCloudStatus = "Uses your Apple Account. Changes may take time to reach other Macs."
    }

    func mode(for calendarIdentifier: String) -> CalendarMode {
        calendarRules[calendarIdentifier] ?? .busyOnly
    }

    func orderedCalendars(_ calendars: [CalendarInfo]) -> [CalendarInfo] {
        let ranks = Dictionary(calendarOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let sharedRanks = Dictionary(sharedCalendarOrder.enumerated().map { ($0.element, $0.offset) }, uniquingKeysWith: { first, _ in first })
        let counts = Dictionary(grouping: calendars, by: Self.orderKey).mapValues(\.count)
        return calendars.enumerated().sorted {
            let leftKey = Self.orderKey($0.element)
            let rightKey = Self.orderKey($1.element)
            let leftShared = counts[leftKey] == 1 ? sharedRanks[leftKey] : nil
            let rightShared = counts[rightKey] == 1 ? sharedRanks[rightKey] : nil
            if leftShared != rightShared { return (leftShared ?? Int.max) < (rightShared ?? Int.max) }
            let left = ranks[$0.element.id] ?? Int.max
            let right = ranks[$1.element.id] ?? Int.max
            return left == right ? $0.offset < $1.offset : left < right
        }.map(\.element)
    }

    private static func orderKey(_ calendar: CalendarInfo) -> String {
        ManagedEventMarker.make("calendar-order|\(calendar.sourceTitle.utf8.count):\(calendar.sourceTitle)|\(calendar.title)")
    }

    func moveCalendar(_ identifier: String, to target: String, after: Bool = false, in calendars: [CalendarInfo]) -> Bool {
        var identifiers = orderedCalendars(calendars).map(\.id)
        guard identifier != target,
              let from = identifiers.firstIndex(of: identifier),
              identifiers.contains(target) else { return false }
        identifiers.remove(at: from)
        guard let to = identifiers.firstIndex(of: target) else { return false }
        identifiers.insert(identifier, at: to + (after ? 1 : 0))
        calendarOrder = identifiers + calendarOrder.filter { !identifiers.contains($0) }
        let byID = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
        let counts = Dictionary(grouping: calendars, by: Self.orderKey).mapValues(\.count)
        let keys = identifiers.compactMap { byID[$0].map(Self.orderKey) }.filter { counts[$0] == 1 }
        sharedCalendarOrder = keys + sharedCalendarOrder.filter { !keys.contains($0) }
        return true
    }

    func setMode(_ mode: CalendarMode, for calendarIdentifier: String) {
        calendarRules[calendarIdentifier] = mode
    }

    func registerCurrentTarget() {
        guard !targetCalendarIdentifier.isEmpty else { return }
        managedTargetCalendarIdentifiers.insert(targetCalendarIdentifier)
    }

    func isBufferEnabled(for calendarIdentifier: String) -> Bool {
        bufferEnabledCalendarIdentifiers.contains(calendarIdentifier)
    }

    func setBufferEnabled(_ enabled: Bool, for calendarIdentifier: String) {
        if enabled {
            bufferEnabledCalendarIdentifiers.insert(calendarIdentifier)
        } else {
            bufferEnabledCalendarIdentifiers.remove(calendarIdentifier)
        }
    }

    func syncSettings() -> SyncSettings {
        SyncSettings(
            targetCalendarIdentifier: targetCalendarIdentifier,
            calendarModes: calendarRules,
            bufferMinutes: bufferMinutes,
            bufferEnabledCalendarIdentifiers: bufferEnabledCalendarIdentifiers,
            pastRange: pastRange,
            rangeMonths: rangeMonths,
            mergeDuplicates: mergeDuplicates,
            allDayBlockedWords: allDayBlockedWords,
            deleteEventsBeforeSyncRange: deleteEventsBeforeSyncRange,
            managedTargetCalendarIdentifiers: managedTargetCalendarIdentifiers.union([targetCalendarIdentifier])
        )
    }

    private func saveCalendarRules() {
        guard let data = try? JSONEncoder().encode(calendarRules) else { return }
        defaults.set(data, forKey: Key.calendarRules)
    }
}
