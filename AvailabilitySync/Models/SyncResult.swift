// SyncResult.swift developed by Bob Tianqi Wei

import Foundation

struct SyncResult: Sendable {
    let sourceOccurrences: Int
    let desiredEvents: Int
    let created: Int
    let updated: Int
    let deleted: Int
    let unchanged: Int

    var summary: String {
        "Created \(created), updated \(updated), deleted \(deleted), unchanged \(unchanged)"
    }
}

enum SyncState: Equatable {
    case idle
    case syncing
    case success(String)
    case failure(String)

    var title: String {
        switch self {
        case .idle: "Ready"
        case .syncing: "Syncing…"
        case .success: "Synced"
        case .failure: "Sync failed"
        }
    }

    var detail: String? {
        switch self {
        case .success(let detail), .failure(let detail): detail
        case .idle, .syncing: nil
        }
    }
}
