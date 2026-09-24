import AppKit

/// Janelas na tela (`CGWindowList`). Enter foca. Sem Acessibilidade, não oferece encaixe.
@MainActor
final class WindowProvider: CommandProvider {
    private let listLimit = 20

    func hits(for query: String) -> [LauncherItem] {
        guard query.count >= 2 else { return [] }
        let windows = WindowList.visible()
        let trusted = WindowActions.isTrusted
        if let placement = WindowPlacement.match(in: query) {
            guard trusted else { return [accessHit] }
            let rest = WindowPlacement.remainder(in: query, placement: placement)
            let targets = rest.isEmpty ? Array(windows.prefix(1)) : Self.matched(windows, query: rest)
            return targets.prefix(8).map { placeHit($0, placement) }
        }
        let listed = Self.matched(windows, query: query)
        guard !listed.isEmpty || Self.asksForAccess(query) else { return [] }
        var hits = listed.prefix(listLimit).map(focusHit)
        if !trusted {
            hits.append(accessHit)
        }
        return Array(hits)
    }

    private static func matched(_ windows: [WindowTarget], query: String) -> [WindowTarget] {
        if asksForWindows(query) {
            return windows
        }
        return windows.filter { window in
            let fields = [window.title, window.owner].map(AppSearch.fold)
            return fields.contains { AppSearch.matchRank(name: $0, query: query) != nil }
        }
    }

    private static func asksForWindows(_ query: String) -> Bool {
        ["janela", "janelas", "window", "windows"].contains { name in
            AppSearch.matchRank(name: name, query: query).map { $0 <= 2 } ?? false
        }
    }

    private static func asksForAccess(_ query: String) -> Bool {
        ["acessibilidade", "accessibility", "ajustes"].contains { name in
            AppSearch.matchRank(name: name, query: query).map { $0 <= 4 } ?? false
        }
    }

    private func focusHit(_ window: WindowTarget) -> LauncherItem {
        LauncherItem(
            id: "window.\(window.id)",
            title: window.title.isEmpty ? window.owner : window.title,
            subtitle: window.owner,
            section: "Janelas",
            action: .focusWindow(window),
            kind: .command(symbol: "macwindow")
        )
    }

    private func placeHit(_ window: WindowTarget, _ placement: WindowPlacement) -> LauncherItem {
        let label = window.title.isEmpty ? window.owner : window.title
        return LauncherItem(
            id: "window.\(window.id).\(placement.id)",
            title: "\(label) — \(placement.title)",
            subtitle: window.owner,
            section: "Janelas",
            action: .placeWindow(window, placement),
            kind: .command(symbol: placement.symbol)
        )
    }

    private var accessHit: LauncherItem {
        LauncherItem(
            id: "teclora.accessibility",
            title: "Abrir Ajustes de Acessibilidade",
            subtitle: "Sem isto, as janelas só recebem foco",
            section: "Janelas",
            action: .openAccessibilitySettings,
            kind: .command(symbol: "hand.raised")
        )
    }
}
