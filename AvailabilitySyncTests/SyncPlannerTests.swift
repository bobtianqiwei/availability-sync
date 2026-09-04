// SyncPlannerTests.swift developed by Bob Tianqi Wei

import XCTest
@testable import AvailabilitySync

final class SyncPlannerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_800_000_000)

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
