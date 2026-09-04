// LaunchAtLoginManager.swift developed by Bob Tianqi Wei

import ServiceManagement

@MainActor
final class LaunchAtLoginManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval
    }

    func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            if service.status != .enabled && service.status != .requiresApproval {
                try service.register()
            }
        } else if service.status == .enabled || service.status == .requiresApproval {
            try service.unregister()
        }
    }
}
