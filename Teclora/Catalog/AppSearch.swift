import Foundation

@MainActor
enum AppSearch {
    static let recentLimit = 4

    static func sections(
        from apps: [InstalledApp],
        query: String,
        history: LaunchHistory
    ) -> [LauncherSection] {
        let folded = fold(query)
        var groups: [(String, [LauncherItem])] = []

        if folded.isEmpty {
            let byID = Dictionary(apps.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let recents = history.mostRecent(limit: recentLimit).compactMap { byID[$0] }
            let recentIDs = Set(recents.map(\.id))
            groups.append(("Recentes", recents.map(LauncherItem.application)))
            groups.append((
                "Aplicativos",
                apps.filter { !recentIDs.contains($0.id) }.map(LauncherItem.application)
            ))
            groups.append(("Comandos", [.quit]))
        } else {
            groups.append(("Aplicativos", rankedApps(apps, query: folded, history: history)))
            if matchesQuit(folded) {
                groups.append(("Comandos", [.quit]))
            }
        }

        var sections: [LauncherSection] = []
        var index = 0
        for (title, items) in groups where !items.isEmpty {
            sections.append(LauncherSection(title: title, items: items, startIndex: index))
            index += items.count
        }
        return sections
    }

    static func fold(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func rankedApps(
        _ apps: [InstalledApp],
        query: String,
        history: LaunchHistory
    ) -> [LauncherItem] {
        apps.compactMap { app -> (rank: Int, score: Double, app: InstalledApp)? in
            let keys = [app.name, app.fileName].map(fold)
            guard let rank = keys.compactMap({ matchRank(name: $0, query: query) }).min() else {
                return nil
            }
            return (rank, history.score(for: app.id), app)
        }
        .sorted { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.app.name.localizedStandardCompare(rhs.app.name) == .orderedAscending
        }
        .map { LauncherItem.application($0.app) }
    }

    /// Menor é melhor. `nil` = não casa.
    /// Ordem: exato → prefixo → início de palavra → iniciais ("vsc") → contém → fuzzy.
    static func matchRank(name: String, query: String) -> Int? {
        if name == query { return 0 }
        if name.hasPrefix(query) { return 1 }
        let words = words(in: name)
        if words.contains(where: { $0.hasPrefix(query) }) { return 2 }
        if query.count >= 2, String(words.compactMap(\.first)).hasPrefix(query) { return 3 }
        if name.contains(query) { return 4 }
        if query.count >= 3, isSubsequence(query, of: name) { return 5 }
        return nil
    }

    private static func words(in name: String) -> [Substring] {
        name.split { !$0.isLetter && !$0.isNumber }
    }

    private static func isSubsequence(_ query: String, of name: String) -> Bool {
        var remaining = query[...]
        for char in name where char == remaining.first {
            remaining = remaining.dropFirst()
            if remaining.isEmpty { return true }
        }
        return remaining.isEmpty
    }

    private static func matchesQuit(_ query: String) -> Bool {
        ["sair do teclora", "quit teclora", "fechar teclora"]
            .contains { matchRank(name: $0, query: query).map { $0 <= 4 } ?? false }
    }
}
