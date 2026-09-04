// EventKitManager.swift developed by Bob Tianqi Wei

import AppKit
import Combine
import EventKit

enum CalendarPermissionStatus {
    case notDetermined
    case fullAccess
    case denied
    case restricted
    case writeOnly

    var canReadEvents: Bool {
        self == .fullAccess
    }
}

@MainActor
final class EventKitManager: ObservableObject {
    let eventStore = EKEventStore()

    @Published private(set) var permissionStatus: CalendarPermissionStatus = .notDetermined
    @Published private(set) var calendars: [CalendarInfo] = []

    private var storeChangeObserver: AnyCancellable?

    init() {
        refreshAuthorizationStatus()
        storeChangeObserver = NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshCalendars()
            }
    }

    func requestFullAccess() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            eventStore.requestFullAccessToEvents { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        refreshAuthorizationStatus()
        refreshCalendars()
        return granted
    }

    func refreshAuthorizationStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            permissionStatus = .notDetermined
        case .fullAccess, .authorized:
            permissionStatus = .fullAccess
        case .writeOnly:
            permissionStatus = .writeOnly
        case .denied:
            permissionStatus = .denied
        case .restricted:
            permissionStatus = .restricted
        @unknown default:
            permissionStatus = .denied
        }
    }

    func refreshCalendars() {
        refreshAuthorizationStatus()
        guard permissionStatus.canReadEvents else {
            calendars = []
            return
        }

        calendars = eventStore.calendars(for: .event)
            .map(Self.makeCalendarInfo)
            .sorted {
                if $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedSame {
                    return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                return $0.sourceTitle.localizedCaseInsensitiveCompare($1.sourceTitle) == .orderedAscending
            }
    }

    func calendar(withIdentifier identifier: String) -> EKCalendar? {
        guard !identifier.isEmpty else { return nil }
        return eventStore.calendar(withIdentifier: identifier)
    }

    func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private static func makeCalendarInfo(_ calendar: EKCalendar) -> CalendarInfo {
        let nativeColor = NSColor(cgColor: calendar.cgColor) ?? .systemGray
        let color = nativeColor.usingColorSpace(.deviceRGB) ?? nativeColor
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        return CalendarInfo(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            allowsContentModifications: calendar.allowsContentModifications,
            red: Double(red),
            green: Double(green),
            blue: Double(blue)
        )
    }
}
