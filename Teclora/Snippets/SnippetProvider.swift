import Foundation

/// Busca por nome, atalho e corpo. Enter copia o corpo. "Novo snippet" abre a aba.
@MainActor
final class SnippetProvider: CommandProvider {
    private let store: SnippetStore
    private let emptyLimit = 8

    init(store: SnippetStore) {
        self.store = store
    }

    func hits(for query: String) -> [LauncherItem] {
        var hits = matching(query)
        if query.isEmpty || matchesNew(query) {
            hits.append(newCommand)
        }
        return hits
    }

    private func matching(_ query: String) -> [LauncherItem] {
        let sorted = store.snippets.sorted { $0.createdAt > $1.createdAt }
        if query.isEmpty {
            return sorted.prefix(emptyLimit).map(makeItem)
        }
        return sorted.compactMap { snippet -> (Int, Snippet)? in
            let fields = [snippet.name, snippet.shortcut, snippet.body].map(AppSearch.fold)
            guard let rank = fields.compactMap({ AppSearch.matchRank(name: $0, query: query) }).min() else {
                return nil
            }
            return (rank, snippet)
        }
        .sorted { $0.0 < $1.0 }
        .map { makeItem($0.1) }
    }

    private func matchesNew(_ query: String) -> Bool {
        ["novo snippet", "new snippet", "snippet"].contains { name in
            AppSearch.matchRank(name: name, query: query).map { $0 <= 4 } ?? false
        }
    }

    private var newCommand: LauncherItem {
        LauncherItem(
            id: "teclora.snippet.new",
            title: "Novo snippet",
            subtitle: "Comando",
            section: "Comandos",
            action: .newSnippet,
            kind: .command(symbol: "plus.rectangle.on.rectangle")
        )
    }

    private func makeItem(_ snippet: Snippet) -> LauncherItem {
        let shortcut = snippet.shortcut.isEmpty ? nil : snippet.shortcut
        return LauncherItem(
            id: "snippet.\(snippet.id.uuidString)",
            title: snippet.name,
            subtitle: shortcut ?? preview(snippet.body),
            section: "Snippets",
            action: .copyText(snippet.body),
            kind: .command(symbol: "text.quote")
        )
    }

    private func preview(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        if collapsed.count <= 80 { return collapsed }
        return String(collapsed.prefix(77)) + "…"
    }
}
