import Foundation

/// Se "responder ao chamar" está ligado, o wake name vira um hit do launcher.
@MainActor
final class TecpetProvider: CommandProvider {
    private let store: TecpetStore

    init(store: TecpetStore) {
        self.store = store
    }

    func hits(for query: String) -> [LauncherItem] {
        guard store.respondToWake, !store.muted, !query.isEmpty else { return [] }
        let wake = AppSearch.fold(store.wakeName)
        guard !wake.isEmpty else { return [] }
        guard AppSearch.matchRank(name: wake, query: query).map({ $0 <= 1 }) ?? false else { return [] }
        let name = store.wakeName.isEmpty ? (store.species?.defaultName ?? "Tecpet") : store.wakeName
        return [
            LauncherItem(
                id: "teclora.tecpet.wake",
                title: "Falar com \(name)",
                subtitle: "Tecpet",
                section: "Comandos",
                action: .openTecpet,
                kind: .command(symbol: "pawprint")
            ),
        ]
    }
}
