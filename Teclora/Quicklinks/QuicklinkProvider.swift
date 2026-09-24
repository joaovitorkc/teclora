import Foundation

/// Quicklinks cadastrados. A busca casa o nome e o destino; Enter abre.
@MainActor
final class QuicklinkProvider: CommandProvider {
    private let store: QuicklinkStore

    init(store: QuicklinkStore) {
        self.store = store
    }

    func hits(for query: String) -> [LauncherItem] {
        let links = store.links
        if query.isEmpty {
            return links.map(makeItem)
        }
        return links.compactMap { link -> (Int, Quicklink)? in
            let fields = [link.name, link.target].map(AppSearch.fold)
            guard let rank = fields.compactMap({ AppSearch.matchRank(name: $0, query: query) }).min() else {
                return nil
            }
            return (rank, link)
        }
        .sorted { $0.0 < $1.0 }
        .map { makeItem($0.1) }
    }

    private func makeItem(_ link: Quicklink) -> LauncherItem {
        LauncherItem(
            id: "quicklink.\(link.id.uuidString)",
            title: link.name,
            subtitle: link.target,
            section: "Quicklinks",
            action: .openTarget(link.target),
            kind: .command(symbol: "link")
        )
    }
}
