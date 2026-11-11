import AppKit
import ServiceManagement

/// Sunlight as a login item. Tablecloth installs none: setup offers none and nothing registers one. What
/// is left is the read the uninstall needs, and the unregister that takes away an earlier version's.
enum LoginItem {
    static var status: SMAppService.Status { SMAppService.mainApp.status }

    static func unregister() {
        let service = SMAppService.mainApp
        guard service.status == .enabled || service.status == .requiresApproval else { return }
        do {
            try service.unregister()
        } catch {
            Log.note("Login item: unregister failed — \(error.localizedDescription)")
        }
    }

    static func describe(_ status: SMAppService.Status) -> String {
        switch status {
        case .enabled: return "enabled"
        case .requiresApproval: return "requires approval in System Settings › General › Login Items"
        case .notRegistered: return "not registered"
        case .notFound: return "not found (rebuilt bundle? sign with SIGN=… to keep a stable identity)"
        @unknown default: return "unknown (\(status.rawValue))"
        }
    }
}
