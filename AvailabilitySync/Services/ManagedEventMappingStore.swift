// ManagedEventMappingStore.swift developed by Bob Tianqi Wei

import Foundation

struct ManagedEventReference: Codable, Equatable {
    let eventIdentifier: String
    let calendarIdentifier: String
}

final class ManagedEventMappingStore {
    private static let key = "managedEventMappings"

    private let defaults: UserDefaults
    private var mappings: [String: ManagedEventReference]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([String: ManagedEventReference].self, from: data) {
            mappings = decoded
        } else {
            mappings = [:]
        }
    }

    func syncIdentifier(for eventIdentifier: String, calendarIdentifier: String) -> String? {
        mappings.first { _, reference in
            reference.eventIdentifier == eventIdentifier &&
            reference.calendarIdentifier == calendarIdentifier
        }?.key
    }

    func references(for calendarIdentifier: String) -> [String: ManagedEventReference] {
        mappings.filter { $0.value.calendarIdentifier == calendarIdentifier }
    }

    func set(_ reference: ManagedEventReference, for syncIdentifier: String) {
        mappings[syncIdentifier] = reference
    }

    func remove(syncIdentifier: String) {
        mappings.removeValue(forKey: syncIdentifier)
    }

    func save() {
        guard let data = try? JSONEncoder().encode(mappings) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
