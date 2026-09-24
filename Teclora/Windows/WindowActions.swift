import AppKit
import ApplicationServices

@MainActor
extension WindowPlacement {
    var id: String {
        switch self {
        case .left: "left"
        case .right: "right"
        case .maximize: "maximize"
        case .center: "center"
        }
    }

    var title: String {
        switch self {
        case .left: "esquerda"
        case .right: "direita"
        case .maximize: "maximizar"
        case .center: "centro"
        }
    }

    var symbol: String {
        switch self {
        case .left: "rectangle.lefthalf.filled"
        case .right: "rectangle.righthalf.filled"
        case .maximize: "rectangle.expand.vertical"
        case .center: "rectangle.center.inset.filled"
        }
    }

    fileprivate var words: [String] {
        switch self {
        case .left: ["esquerda", "left"]
        case .right: ["direita", "right"]
        case .maximize: ["maximizar", "maximize", "maximiza"]
        case .center: ["centro", "centralizar", "center"]
        }
    }

    static func match(in query: String) -> WindowPlacement? {
        let all: [WindowPlacement] = [.left, .right, .maximize, .center]
        return all.first { placement in
            placement.words.contains { word in
                AppSearch.matchRank(name: word, query: query).map { $0 <= 4 } ?? false
            }
        }
    }

    static func remainder(in query: String, placement: WindowPlacement) -> String {
        var text = query
        for word in placement.words where text.contains(word) {
            text = text.replacingOccurrences(of: word, with: " ")
        }
        return AppSearch.fold(text)
    }
}

/// Focar funciona sem Acessibilidade. Encaixar só com o processo autorizado.
@MainActor
enum WindowActions {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func focus(_ target: WindowTarget) {
        if isTrusted, let element = axWindow(target) {
            AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        }
        NSRunningApplication(processIdentifier: target.pid)?.activate(options: [.activateAllWindows])
    }

    static func place(_ target: WindowTarget, _ placement: WindowPlacement) {
        guard isTrusted, let element = axWindow(target) else {
            TecloraLog.error("Sem Acessibilidade para mover a janela")
            return
        }
        focus(target)
        guard let frame = frame(for: placement, windowID: target.id) else { return }
        var origin = axOrigin(frame)
        var size = frame.size
        guard let position = AXValueCreate(.cgPoint, &origin),
              let axSize = AXValueCreate(.cgSize, &size) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, position)
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axSize)
    }

    static func openAccessibilitySettings() {
        let urls = [
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility",
        ]
        for raw in urls {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) { return }
        }
        TecloraLog.error("Não abriu Ajustes de Acessibilidade")
    }

    private static func axWindow(_ target: WindowTarget) -> AXUIElement? {
        let app = AXUIElementCreateApplication(target.pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        if !target.title.isEmpty {
            for window in windows {
                var name: CFTypeRef?
                AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &name)
                if (name as? String) == target.title { return window }
            }
        }
        return windows.first
    }

    private static func frame(for placement: WindowPlacement, windowID: UInt32) -> CGRect? {
        guard let screen = screen(containing: windowID) else { return nil }
        let visible = screen.visibleFrame
        switch placement {
        case .left:
            return CGRect(x: visible.minX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .right:
            return CGRect(x: visible.midX, y: visible.minY, width: visible.width / 2, height: visible.height)
        case .maximize:
            return visible
        case .center:
            let width = visible.width * 0.62
            let height = visible.height * 0.72
            return CGRect(
                x: visible.midX - width / 2,
                y: visible.midY - height / 2,
                width: width,
                height: height
            )
        }
    }

    private static func screen(containing windowID: UInt32) -> NSScreen? {
        guard let raw = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let bounds = raw.first?[kCGWindowBounds as String] as? [String: Any],
              let x = (bounds["X"] as? NSNumber)?.doubleValue,
              let y = (bounds["Y"] as? NSNumber)?.doubleValue,
              let height = (bounds["Height"] as? NSNumber)?.doubleValue else {
            return NSScreen.main
        }
        let primary = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        let cocoaY = primary - y - height
        let point = CGPoint(x: x + 8, y: cocoaY + 8)
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    /// AX usa a origem no canto superior do ecrã principal.
    private static func axOrigin(_ cocoa: CGRect) -> CGPoint {
        let primary = NSScreen.screens.map(\.frame.maxY).max() ?? 0
        return CGPoint(x: cocoa.minX, y: primary - cocoa.maxY)
    }
}
