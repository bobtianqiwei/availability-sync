// SyncEngine.swift developed by Bob Tianqi Wei

import EventKit
import Foundation

enum SyncEngineError: LocalizedError {
    case targetNotSelected
    case targetNotFound
    case targetNotWritable
    case dateRangeUnavailable

    var errorDescription: String? {
        switch self {
        case .targetNotSelected: "Choose a target calendar before syncing."
        case .targetNotFound: "The selected target calendar is no longer available."
        case .targetNotWritable: "The selected target calendar is read-only."
        case .dateRangeUnavailable: "The sync date range could not be created."
        }
    }
}

@MainActor
final class SyncEngine {
    private let eventStore: EKEventStore

    init(eventStore: EKEventStore) {
        self.eventStore = eventStore
    }

    func sync(using settings: SyncSettings) throws -> SyncResult {
        guard !settings.targetCalendarIdentifier.isEmpty else {
            throw SyncEngineError.targetNotSelected
        }
        guard let targetCalendar = eventStore.calendar(withIdentifier: settings.targetCalendarIdentifier) else {
            throw SyncEngineError.targetNotFound
        }
        guard targetCalendar.allowsContentModifications else {
            throw SyncEngineError.targetNotWritable
        }

        let now = Date()
        let calendar = Calendar.current
        guard let rangeStart = calendar.date(byAdding: .day, value: -2, to: now),
              let rangeEnd = calendar.date(byAdding: .month, value: settings.rangeMonths, to: now),
              let cleanupStart = calendar.date(byAdding: .day, value: -30, to: now),
              let cleanupEnd = calendar.date(byAdding: .month, value: 13, to: now) else {
            throw SyncEngineError.dateRangeUnavailable
        }

        let sourceCalendars = eventStore.calendars(for: .event).filter { source in
            source.calendarIdentifier != targetCalendar.calendarIdentifier &&
            settings.calendarModes[source.calendarIdentifier, default: .busyOnly] != .ignore
        }
        let sourcePredicate = eventStore.predicateForEvents(
            withStart: rangeStart,
            end: rangeEnd,
            calendars: sourceCalendars
        )
        let sourceEvents = eventStore.events(matching: sourcePredicate)
        let occurrences = sourceEvents.compactMap { event -> SourceOccurrence? in
            guard event.status != .canceled,
                  event.availability != .free,
                  !ManagedEventMarker.isManaged(event.notes),
                  let start = event.startDate,
                  let end = event.endDate else {
                return nil
            }

            let mode = settings.calendarModes[event.calendar.calendarIdentifier, default: .busyOnly]
            guard mode != .ignore else { return nil }

            let rawTitle = (event.title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let revealsTitle = mode == .showTitle && !rawTitle.isEmpty
            let title = revealsTitle ? rawTitle : "Busy"
            let itemIdentifier = event.eventIdentifier ?? event.calendarItemIdentifier
            let identity = "\(event.calendar.calendarIdentifier)|\(itemIdentifier)"

            return SourceOccurrence(
                identity: identity,
                title: title,
                start: start,
                end: end,
                isAllDay: event.isAllDay,
                revealsTitle: revealsTitle
            )
        }
        let desired = SyncPlanner.desiredEvents(
            from: occurrences,
            mergeDuplicates: settings.mergeDuplicates
        )

        var created = 0
        var updated = 0
        var deleted = 0
        var unchanged = 0

        for identifier in settings.managedTargetCalendarIdentifiers where identifier != targetCalendar.calendarIdentifier {
            guard let oldTarget = eventStore.calendar(withIdentifier: identifier) else { continue }
            deleted += try removeManagedEvents(
                from: oldTarget,
                start: cleanupStart,
                end: cleanupEnd
            )
        }

        let targetPredicate = eventStore.predicateForEvents(
            withStart: cleanupStart,
            end: cleanupEnd,
            calendars: [targetCalendar]
        )
        let targetEvents = eventStore.events(matching: targetPredicate)
        var existingByMarker: [String: [EKEvent]] = [:]
        var legacyEvents: [EKEvent] = []

        for event in targetEvents {
            guard let notes = event.notes else { continue }
            if notes.hasPrefix(ManagedEventMarker.currentPrefix) {
                existingByMarker[notes, default: []].append(event)
            } else if ManagedEventMarker.legacyPrefixes.contains(where: { notes.hasPrefix($0) }) {
                legacyEvents.append(event)
            }
        }

        for (marker, desiredEvent) in desired {
            if var matches = existingByMarker.removeValue(forKey: marker), !matches.isEmpty {
                let existing = matches.removeFirst()
                if apply(desiredEvent, to: existing, targetCalendar: targetCalendar) {
                    try eventStore.save(existing, span: .thisEvent, commit: false)
                    updated += 1
                } else {
                    unchanged += 1
                }

                for duplicate in matches {
                    try eventStore.remove(duplicate, span: .thisEvent, commit: false)
                    deleted += 1
                }
            } else {
                let event = EKEvent(eventStore: eventStore)
                event.calendar = targetCalendar
                event.title = desiredEvent.title
                event.startDate = desiredEvent.start
                event.endDate = desiredEvent.end
                event.isAllDay = desiredEvent.isAllDay
                event.notes = desiredEvent.marker
                event.availability = .busy
                try eventStore.save(event, span: .thisEvent, commit: false)
                created += 1
            }
        }

        for events in existingByMarker.values {
            for event in events {
                try eventStore.remove(event, span: .thisEvent, commit: false)
                deleted += 1
            }
        }

        for event in legacyEvents {
            try eventStore.remove(event, span: .thisEvent, commit: false)
            deleted += 1
        }

        try eventStore.commit()
        return SyncResult(
            sourceOccurrences: sourceEvents.count,
            desiredEvents: desired.count,
            created: created,
            updated: updated,
            deleted: deleted,
            unchanged: unchanged
        )
    }

    private func removeManagedEvents(from calendar: EKCalendar, start: Date, end: Date) throws -> Int {
        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: [calendar])
        let managedEvents = eventStore.events(matching: predicate).filter {
            ManagedEventMarker.isManaged($0.notes)
        }
        for event in managedEvents {
            try eventStore.remove(event, span: .thisEvent, commit: false)
        }
        return managedEvents.count
    }

    private func apply(_ desired: DesiredEvent, to event: EKEvent, targetCalendar: EKCalendar) -> Bool {
        var changed = false

        changed = assign(desired.title, to: &event.title) || changed
        if abs(event.startDate.timeIntervalSince(desired.start)) >= 1 {
            event.startDate = desired.start
            changed = true
        }
        if abs(event.endDate.timeIntervalSince(desired.end)) >= 1 {
            event.endDate = desired.end
            changed = true
        }
        if event.isAllDay != desired.isAllDay {
            event.isAllDay = desired.isAllDay
            changed = true
        }
        if event.calendar.calendarIdentifier != targetCalendar.calendarIdentifier {
            event.calendar = targetCalendar
            changed = true
        }
        if event.notes != desired.marker {
            event.notes = desired.marker
            changed = true
        }
        if event.availability != .busy {
            event.availability = .busy
            changed = true
        }
        if event.location != nil {
            event.location = nil
            changed = true
        }
        if event.structuredLocation != nil {
            event.structuredLocation = nil
            changed = true
        }
        if event.url != nil {
            event.url = nil
            changed = true
        }
        if event.hasAlarms {
            event.alarms = nil
            changed = true
        }
        if !(event.recurrenceRules ?? []).isEmpty {
            event.recurrenceRules = nil
            changed = true
        }
        return changed
    }

    private func assign(_ value: String, to destination: inout String!) -> Bool {
        guard destination != value else { return false }
        destination = value
        return true
    }
}
