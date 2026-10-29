// SyncPlannerTests.swift developed by Bob Tianqi Wei

import XCTest
@testable import AvailabilitySync

private final class TestCloudSettingsStore: CloudSettingsStorage {
    var values: [String: Any] = [:]
    var writes = 0

    func object(forKey key: String) -> Any? { values[key] }
    func set(_ value: Any?, forKey key: String) {
        values[key] = value
        writes += 1
    }
    func synchronize() -> Bool { true }
}

final class SyncPlannerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    func testCalendarOrderMatchesAcrossDifferentLocalIdentifiers() throws {
        let suite = "AvailabilitySyncTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cloud = TestCloudSettingsStore()
        let settings = SettingsStore(defaults: defaults, cloudStore: cloud)
        func calendar(_ id: String, _ title: String) -> CalendarInfo {
            CalendarInfo(id: id, title: title, sourceTitle: "Account", allowsContentModifications: true, red: 0, green: 0, blue: 0)
        }
        let calendars = [calendar("a", "Work"), calendar("b", "Home")]
        settings.iCloudSyncEnabled = true
        XCTAssertTrue(settings.moveCalendar("a", to: "b", after: true, in: calendars))
        let otherSuite = "AvailabilitySyncTests.\(UUID().uuidString)"
        let otherDefaults = try XCTUnwrap(UserDefaults(suiteName: otherSuite))
        defer { otherDefaults.removePersistentDomain(forName: otherSuite) }
        let other = SettingsStore(defaults: otherDefaults, cloudStore: cloud)
        other.iCloudSyncEnabled = true
        let remote = [calendar("x", "Work"), calendar("y", "Home"), calendar("z", "Extra")]
        XCTAssertEqual(other.orderedCalendars(remote).map(\.id), ["y", "x", "z"])
    }

    @MainActor
    func testCloudSettingsAreOptInAndKeepDeviceDataLocal() throws {
        let suite = "AvailabilitySyncTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cloud = TestCloudSettingsStore()
        let settings = SettingsStore(defaults: defaults, cloudStore: cloud)
        settings.rangeMonths = 6
        XCTAssertTrue(cloud.values.isEmpty)
        cloud.values["settings.v1.rangeMonths"] = 12
        settings.iCloudSyncEnabled = true
        XCTAssertEqual(settings.rangeMonths, 12)
        settings.bufferMinutes = 30
        XCTAssertEqual(cloud.values["settings.v1.bufferMinutes"] as? Int, 30)
        settings.targetCalendarIdentifier = "local-target"
        settings.setMode(.ignore, for: "local-source")
        settings.setBufferEnabled(true, for: "local-source")
        settings.launchAtLogin = true
        settings.lastSyncDate = Date()
        XCTAssertEqual(cloud.values.count, 8)
        XCTAssertFalse(cloud.values.description.contains("local-target"))
        XCTAssertFalse(cloud.values.description.contains("local-source"))
        settings.iCloudSyncEnabled = false
        settings.bufferMinutes = 5
        XCTAssertEqual(cloud.values["settings.v1.bufferMinutes"] as? Int, 30)
        cloud.values["settings.v1.rangeMonths"] = 2
        settings.receiveCloudSettings()
        XCTAssertEqual(settings.rangeMonths, 12)
    }

    @MainActor
    func testCloudSettingsValidateIncomingValuesWithoutEcho() throws {
        let suite = "AvailabilitySyncTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let cloud = TestCloudSettingsStore()
        let settings = SettingsStore(defaults: defaults, cloudStore: cloud)
        settings.iCloudSyncEnabled = true
        let writes = cloud.writes
        cloud.values["settings.v1.rangeMonths"] = 99
        cloud.values["settings.v1.syncIntervalMinutes"] = 1
        cloud.values["settings.v1.allDayBlockedWords"] = ""
        settings.receiveCloudSettings()
        XCTAssertEqual(settings.rangeMonths, 4)
        XCTAssertEqual(settings.syncIntervalMinutes, 1)
        XCTAssertEqual(settings.allDayBlockedWords, "")
        XCTAssertEqual(cloud.writes, writes)
        let restored = SettingsStore(defaults: defaults, cloudStore: cloud)
        XCTAssertEqual(restored.syncIntervalMinutes, 1)
        XCTAssertTrue(restored.iCloudSyncEnabled)
    }

    func testAllDayFilter() {
        XCTAssertFalse(SyncPlanner.shouldInclude(title: "Bob’s BIRTHDAY", isAllDay: true, isFree: false, blockedWords: "birthday, 生日"))
        XCTAssertFalse(SyncPlanner.shouldInclude(title: "朋友生日", isAllDay: true, isFree: true, blockedWords: "birthday，生日"))
        XCTAssertTrue(SyncPlanner.shouldInclude(title: "Birthday lunch", isAllDay: false, isFree: false, blockedWords: "birthday"))
        XCTAssertTrue(SyncPlanner.shouldInclude(title: "Birthday", isAllDay: true, isFree: true, blockedWords: " , \n"))
        XCTAssertTrue(SyncPlanner.shouldInclude(title: "Trip", isAllDay: true, isFree: true, blockedWords: "birthday"))
        XCTAssertFalse(SyncPlanner.shouldInclude(title: "Meeting", isAllDay: false, isFree: true, blockedWords: ""))
    }

    func testMultiDayAllDayEventPreservesFullSpan() {
        let end = start.addingTimeInterval(3 * 86400)
        let occurrence = SourceOccurrence(identity: "trip", title: "Trip", start: start, end: end, isAllDay: true, revealsTitle: true)
        for mergeDuplicates in [true, false] {
            let desired = SyncPlanner.desiredEvents(from: [occurrence], mergeDuplicates: mergeDuplicates)
            XCTAssertEqual(desired.count, 1)
            XCTAssertEqual(desired.values.first?.start, start)
            XCTAssertEqual(desired.values.first?.end, end)
            XCTAssertEqual(desired.values.first?.isAllDay, true)
        }
    }

    @MainActor
    func testBlockedWordsPersistIncludingEmptyValue() throws {
        let suite = "AvailabilitySyncTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let settings = SettingsStore(defaults: defaults)
        XCTAssertEqual(settings.allDayBlockedWords, "birthday, 生日")
        settings.allDayBlockedWords = "holiday"
        XCTAssertEqual(SettingsStore(defaults: defaults).syncSettings().allDayBlockedWords, "holiday")
        settings.allDayBlockedWords = ""
        XCTAssertEqual(SettingsStore(defaults: defaults).allDayBlockedWords, "")
    }

    func testBusyOnlyOutputContainsNoPrivateMetadata() {
        let occurrence = SourceOccurrence(
            identity: "private-calendar|private-event",
            title: "Busy",
            start: start,
            end: start.addingTimeInterval(3600),
            isAllDay: false,
            revealsTitle: false
        )

        let desired = SyncPlanner.desiredEvents(from: [occurrence], mergeDuplicates: true)

        XCTAssertEqual(desired.count, 1)
        XCTAssertEqual(desired.values.first?.title, "Busy")
        XCTAssertFalse(desired.keys.first?.contains("private-calendar") ?? true)
        XCTAssertFalse(desired.keys.first?.contains("private-event") ?? true)
    }

    func testVisibleTitleWinsOverBusyAtSameInterval() {
        let end = start.addingTimeInterval(3600)
        let occurrences = [
            SourceOccurrence(identity: "one", title: "Busy", start: start, end: end, isAllDay: false, revealsTitle: false),
            SourceOccurrence(identity: "two", title: "Team Meeting", start: start, end: end, isAllDay: false, revealsTitle: true)
        ]

        let desired = SyncPlanner.desiredEvents(from: occurrences, mergeDuplicates: true)

        XCTAssertEqual(desired.count, 1)
        XCTAssertEqual(desired.values.first?.title, "Team Meeting")
    }

    func testDuplicateMergeCanBeDisabled() {
        let end = start.addingTimeInterval(3600)
        let occurrences = [
            SourceOccurrence(identity: "one", title: "Busy", start: start, end: end, isAllDay: false, revealsTitle: false),
            SourceOccurrence(identity: "two", title: "Busy", start: start, end: end, isAllDay: false, revealsTitle: false)
        ]

        XCTAssertEqual(SyncPlanner.desiredEvents(from: occurrences, mergeDuplicates: true).count, 1)
        XCTAssertEqual(SyncPlanner.desiredEvents(from: occurrences, mergeDuplicates: false).count, 2)
    }
}
