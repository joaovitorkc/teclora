import Foundation

/// Funde o catálogo de apps com os providers e reusa o ranking de `AppSearch`.
@MainActor
enum SearchIndex {
    private static let emptyOrder = [
        "Recentes", "Clipboard", "Snippets", "Quicklinks", "Comandos", "Aplicativos",
    ]
    private static let queryOrder = [
        "Calculadora", "Aplicativos", "Clipboard", "Snippets", "Quicklinks", "Comandos",
    ]

    static func sections(
        apps: [InstalledApp],
        query: String,
        history: LaunchHistory,
        providers: [CommandProvider]
    ) -> [LauncherSection] {
        let folded = AppSearch.fold(query)
        var grouped: [String: [LauncherItem]] = [:]
        for section in AppSearch.sections(from: apps, query: query, history: history) {
            grouped[section.title, default: []].append(contentsOf: section.items)
        }
        for provider in providers {
            for hit in provider.hits(for: folded) {
                grouped[hit.section, default: []].append(hit)
            }
        }

        let order = folded.isEmpty ? emptyOrder : queryOrder
        let extras = grouped.keys.filter { !order.contains($0) }.sorted()
        var result: [LauncherSection] = []
        var index = 0
        for title in order + extras {
            let items = grouped[title] ?? []
            guard !items.isEmpty else { continue }
            result.append(LauncherSection(title: title, items: items, startIndex: index))
            index += items.count
        }
        return result
    }
}
