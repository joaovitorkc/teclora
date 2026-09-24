import AppKit

/// Lista janelas visíveis. Não move nada: isso fica em `WindowActions`.
enum WindowList {
    private static let blockedOwners: Set<String> = [
        "Window Server", "Dock", "SystemUIServer", "Control Center", "Notification Center",
    ]

    static func visible() -> [WindowTarget] {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] else { return [] }
        let selfPID = ProcessInfo.processInfo.processIdentifier
        var windows: [WindowTarget] = []
        for info in raw {
            guard let target = target(from: info, selfPID: selfPID) else { continue }
            windows.append(target)
        }
        return windows
    }

    private static func target(from info: [String: Any], selfPID: Int32) -> WindowTarget? {
        let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue ?? 0
        guard layer == 0 else { return nil }
        let pid = (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? 0
        guard pid != 0, pid != selfPID else { return nil }
        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
        guard !blockedOwners.contains(owner) else { return nil }
        guard let bounds = rect(info[kCGWindowBounds as String]), bounds.width >= 80, bounds.height >= 60 else {
            return nil
        }
        let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value ?? 0
        guard number != 0 else { return nil }
        let title = (info[kCGWindowName as String] as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return WindowTarget(id: number, pid: pid, title: title, owner: owner)
    }

    private static func rect(_ value: Any?) -> CGRect? {
        guard let bounds = value as? [String: Any] else { return nil }
        guard let x = (bounds["X"] as? NSNumber)?.doubleValue,
              let y = (bounds["Y"] as? NSNumber)?.doubleValue,
              let width = (bounds["Width"] as? NSNumber)?.doubleValue,
              let height = (bounds["Height"] as? NSNumber)?.doubleValue else { return nil }
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
