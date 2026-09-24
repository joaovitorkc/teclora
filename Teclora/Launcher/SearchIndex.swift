import Foundation

/// Funde o catálogo de apps com os providers e reusa o ranking de `AppSearch`.
@MainActor
enum SearchIndex {
    static func sections(
        apps: [InstalledApp],
        query: String,
        history: LaunchHistory,
        providers: [CommandProvider]
    ) -> [LauncherSection] {
        var sections = AppSearch.sections(from: apps, query: query, history: history)
        var count = sections.reduce(0) { $0 + $1.items.count }
        let folded = AppSearch.fold(query)
        var grouped: [String: [LauncherItem]] = [:]
        var order: [String] = []

        for provider in providers {
            for hit in provider.hits(for: folded) {
                if grouped[hit.section] == nil {
                    order.append(hit.section)
                }
                grouped[hit.section, default: []].append(hit)
            }
        }

        for title in order {
            let items = grouped[title] ?? []
            guard !items.isEmpty else { continue }
            sections.append(LauncherSection(title: title, items: items, startIndex: count))
            count += items.count
        }
        return sections
    }
}
