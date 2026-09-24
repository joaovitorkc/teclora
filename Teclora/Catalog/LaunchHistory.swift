import Foundation

/// Quantas vezes e quando cada app foi aberto pelo Teclora.
/// Alimenta "Recentes" e desempata a busca (o que você usa sobe).
@MainActor
final class LaunchHistory {
    private struct Entry {
        var count: Double
        var lastUsed: Double
    }

    private let defaults: UserDefaults
    private let key = "launchHistory.v1"
    private var entries: [String: Entry] = [:]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let raw = defaults.dictionary(forKey: key) as? [String: [Double]] ?? [:]
        for (id, values) in raw where values.count == 2 {
            entries[id] = Entry(count: values[0], lastUsed: values[1])
        }
    }

    func record(_ id: String, now: Date = .now) {
        var entry = entries[id] ?? Entry(count: 0, lastUsed: 0)
        entry.count += 1
        entry.lastUsed = now.timeIntervalSince1970
        entries[id] = entry
        persist()
    }

    /// Frequência com decaimento: uso de ontem pesa mais que uso do mês passado.
    func score(for id: String, now: Date = .now) -> Double {
        guard let entry = entries[id] else { return 0 }
        let ageDays = max(0, now.timeIntervalSince1970 - entry.lastUsed) / 86_400
        return entry.count / (1 + ageDays / 7)
    }

    func mostRecent(limit: Int) -> [String] {
        entries
            .sorted { $0.value.lastUsed > $1.value.lastUsed }
            .prefix(limit)
            .map(\.key)
    }

    private func persist() {
        // Mantém o histórico enxuto: só os 200 mais recentes.
        if entries.count > 200 {
            let keep = Set(mostRecent(limit: 200))
            entries = entries.filter { keep.contains($0.key) }
        }
        let raw = entries.mapValues { [$0.count, $0.lastUsed] }
        defaults.set(raw, forKey: key)
    }
}
