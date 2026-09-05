// CalendarRule.swift developed by Bob Tianqi Wei

import Foundation

enum PastRange: String, CaseIterable, Identifiable, Sendable {
    case none
    case twoDays
    case oneWeek
    case oneMonth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .twoDays: "2 days"
        case .oneWeek: "1 week"
        case .oneMonth: "1 month"
        }
    }
}

enum CalendarMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case showTitle
    case busyOnly
    case ignore

    var id: String { rawValue }

    var label: String {
        switch self {
        case .showTitle: "Show Title"
        case .busyOnly: "Busy Only"
        case .ignore: "Ignore"
        }
    }
}

struct CalendarRule: Codable, Hashable, Identifiable {
    let calendarIdentifier: String
    var mode: CalendarMode

    var id: String { calendarIdentifier }
}

struct CalendarInfo: Hashable, Identifiable {
    let id: String
    let title: String
    let sourceTitle: String
    let allowsContentModifications: Bool
    let red: Double
    let green: Double
    let blue: Double

    var displayName: String {
        sourceTitle.isEmpty ? title : "\(title) — \(sourceTitle)"
    }
}

struct SyncSettings: Sendable {
    let targetCalendarIdentifier: String
    let calendarModes: [String: CalendarMode]
    let pastRange: PastRange
    let rangeMonths: Int
    let mergeDuplicates: Bool
    let managedTargetCalendarIdentifiers: Set<String>
}
