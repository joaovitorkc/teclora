import Foundation

/// Hits de clipboard para o launcher. Enter copia; a busca casa o texto.
@MainActor
final class ClipboardProvider: CommandProvider {
    private let store: ClipboardStore
    private let emptyLimit = 8

    init(store: ClipboardStore) {
        self.store = store
    }

    func hits(for query: String) -> [LauncherItem] {
        let sorted = store.entries
        if query.isEmpty {
            return sorted.prefix(emptyLimit).map(makeItem)
        }
        return sorted.compactMap { entry -> (Int, ClipboardEntry)? in
            let haystack = AppSearch.fold(entry.text)
            guard let rank = AppSearch.matchRank(name: haystack, query: query) else { return nil }
            return (rank, entry)
        }
        .sorted { lhs, rhs in
            if lhs.0 != rhs.0 { return lhs.0 < rhs.0 }
            if lhs.1.pinned != rhs.1.pinned { return lhs.1.pinned && !rhs.1.pinned }
            return lhs.1.createdAt > rhs.1.createdAt
        }
        .map { makeItem($0.1) }
    }

    private func makeItem(_ entry: ClipboardEntry) -> LauncherItem {
        LauncherItem(
            id: "clipboard.\(entry.id.uuidString)",
            title: Self.preview(entry.text),
            subtitle: entry.pinned ? "Fixado" : Self.stamp(entry.createdAt),
            section: "Clipboard",
            action: .copyClipboard(entry.id),
            kind: .clipboard(id: entry.id, pinned: entry.pinned)
        )
    }

    private static func preview(_ text: String) -> String {
        let collapsed = text.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        if collapsed.count <= 120 { return collapsed }
        return String(collapsed.prefix(117)) + "…"
    }

    private static func stamp(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}
