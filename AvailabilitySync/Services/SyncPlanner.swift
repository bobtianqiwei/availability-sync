// SyncPlanner.swift developed by Bob Tianqi Wei

import CryptoKit
import Foundation

struct SourceOccurrence {
    let identity: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let revealsTitle: Bool
}

struct DesiredEvent {
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let marker: String
}

enum ManagedEventMarker {
    static let currentPrefix = "__BOB_AVAIL_SYNC_V4__|"
    static let legacyPrefixes = [
        "__BOB_AVAIL_SYNC_V3__|",
        "__BOB_BUSY_SYNC__|",
        "__BOB_AVAIL_SYNC__|"
    ]

    static func isManaged(_ notes: String?) -> Bool {
        guard let notes else { return false }
        return notes.hasPrefix(currentPrefix) || legacyPrefixes.contains { notes.hasPrefix($0) }
    }

    static func make(_ identity: String) -> String {
        let digest = SHA256.hash(data: Data(identity.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return currentPrefix + hash
    }
}

enum ManagedEventNote {
    static let text = """
    This event was automatically synced from another calendar using Availability Sync, an open-source tool developed by Bob Tianqi Wei.
    GitHub: https://github.com/bobtianqiwei/availability-sync
    """
}

enum SyncPlanner {
    private struct IntervalKey: Hashable {
        let startSecond: Int64
        let endSecond: Int64
        let isAllDay: Bool
    }

    static func desiredEvents(from occurrences: [SourceOccurrence], mergeDuplicates: Bool) -> [String: DesiredEvent] {
        if !mergeDuplicates {
            return occurrences.reduce(into: [:]) { result, occurrence in
                let identity = [
                    "single",
                    occurrence.identity,
                    String(epochSecond(occurrence.start)),
                    String(epochSecond(occurrence.end)),
                    occurrence.isAllDay ? "1" : "0"
                ].joined(separator: "|")
                let marker = ManagedEventMarker.make(identity)
                result[marker] = desiredEvent(for: occurrence, marker: marker)
            }
        }

        let grouped = Dictionary(grouping: occurrences) { occurrence in
            IntervalKey(
                startSecond: epochSecond(occurrence.start),
                endSecond: epochSecond(occurrence.end),
                isAllDay: occurrence.isAllDay
            )
        }

        var desired: [String: DesiredEvent] = [:]
        for (interval, items) in grouped {
            let visibleItems = items.filter { $0.revealsTitle && normalizedTitle($0.title) != "busy" }
            let outputItems: [SourceOccurrence]

            if visibleItems.isEmpty {
                guard let first = items.first else { continue }
                outputItems = [SourceOccurrence(
                    identity: "busy",
                    title: "Busy",
                    start: first.start,
                    end: first.end,
                    isAllDay: first.isAllDay,
                    revealsTitle: false
                )]
            } else {
                var seenTitles = Set<String>()
                outputItems = visibleItems.filter { item in
                    seenTitles.insert(normalizedTitle(item.title)).inserted
                }
            }

            for item in outputItems {
                let identity = [
                    "merged",
                    String(interval.startSecond),
                    String(interval.endSecond),
                    interval.isAllDay ? "1" : "0",
                    normalizedTitle(item.title)
                ].joined(separator: "|")
                let marker = ManagedEventMarker.make(identity)
                desired[marker] = desiredEvent(for: item, marker: marker)
            }
        }
        return desired
    }

    private static func desiredEvent(for occurrence: SourceOccurrence, marker: String) -> DesiredEvent {
        DesiredEvent(
            title: occurrence.title,
            start: occurrence.start,
            end: occurrence.end,
            isAllDay: occurrence.isAllDay,
            marker: marker
        )
    }

    private static func epochSecond(_ date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970.rounded())
    }

    private static func normalizedTitle(_ title: String) -> String {
        title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
