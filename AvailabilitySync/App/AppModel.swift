// AppModel.swift developed by Bob Tianqi Wei

import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let settings: SettingsStore
    let eventKit: EventKitManager

    @Published private(set) var syncState: SyncState = .idle

    private let syncEngine: SyncEngine
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hasStarted = false

    init() {
        let settings = SettingsStore()
        let eventKit = EventKitManager()
        self.settings = settings
        self.eventKit = eventKit
        syncEngine = SyncEngine(eventStore: eventKit.eventStore)

        settings.$syncIntervalMinutes
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] minutes in
                self?.scheduleAutomaticSync(every: minutes)
            }
            .store(in: &cancellables)
    }

    var sourceCalendars: [CalendarInfo] {
        eventKit.calendars.filter { $0.id != settings.targetCalendarIdentifier }
    }

    var writableCalendars: [CalendarInfo] {
        eventKit.calendars.filter(\.allowsContentModifications)
    }

    var canSync: Bool {
        eventKit.permissionStatus.canReadEvents &&
        writableCalendars.contains { $0.id == settings.targetCalendarIdentifier } &&
        syncState != .syncing
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        eventKit.refreshCalendars()
        settings.launchAtLogin = launchAtLoginManager.isEnabled
        scheduleAutomaticSync(every: settings.syncIntervalMinutes)

        if eventKit.permissionStatus.canReadEvents && !settings.targetCalendarIdentifier.isEmpty {
            Task { await syncNow() }
        }
    }

    func requestCalendarAccess() async {
        let granted = await eventKit.requestFullAccess()
        syncState = granted ? .idle : .failure("Full Calendar access is required.")
    }

    func setTargetCalendar(_ identifier: String) {
        settings.registerCurrentTarget()
        settings.targetCalendarIdentifier = identifier
        settings.registerCurrentTarget()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginManager.setEnabled(enabled)
            settings.launchAtLogin = launchAtLoginManager.isEnabled
        } catch {
            settings.launchAtLogin = launchAtLoginManager.isEnabled
            syncState = .failure("Launch at Login: \(error.localizedDescription)")
        }
    }

    func syncNow() async {
        guard syncState != .syncing else { return }

        if !eventKit.permissionStatus.canReadEvents {
            if eventKit.permissionStatus == .notDetermined {
                await requestCalendarAccess()
            }
            guard eventKit.permissionStatus.canReadEvents else {
                syncState = .failure("Full Calendar access is required.")
                return
            }
        }

        syncState = .syncing
        settings.registerCurrentTarget()
        await Task.yield()

        do {
            let result = try syncEngine.sync(using: settings.syncSettings())
            settings.lastSyncDate = Date()
            syncState = .success(result.summary)
            eventKit.refreshCalendars()
        } catch {
            eventKit.eventStore.reset()
            eventKit.refreshCalendars()
            syncState = .failure(error.localizedDescription)
        }
    }

    private func scheduleAutomaticSync(every minutes: Int) {
        syncTimer?.invalidate()
        let interval = TimeInterval(minutes * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.syncNow()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        syncTimer = timer
    }
}
