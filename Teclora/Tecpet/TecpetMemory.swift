import Foundation

struct TecpetTurn: Codable {
    var role: String
    var text: String
}

enum ProfileWrite {
    case saved
    case invalidJSON
    case tooLarge
}

/// profile.json (2 KB), summary.md (~1500), turns.jsonl (até 12). Sem chamada extra ao modelo.
@MainActor
final class TecpetMemory {
    private let root: URL

    init() {
        root = CursorLayout.tecpetDirectory() ?? URL(fileURLWithPath: NSTemporaryDirectory())
    }

    func profileText() -> String {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("profile.json")),
              data.count <= 2048,
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    func summaryText() -> String {
        let text = (try? String(contentsOf: root.appendingPathComponent("summary.md"), encoding: .utf8)) ?? ""
        if text.count <= 1500 { return text }
        return String(text.suffix(1500))
    }

    func recentTurns(limit: Int = 6) -> [TecpetTurn] {
        Array(loadTurns().suffix(limit))
    }

    /// O mesmo texto do Send. A contagem da UI é este texto ÷ 4, não o uso faturado.
    func prompt(persona: String, user: String) -> String {
        let turns = recentTurns().map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        return """
        \(persona)
        Perfil:
        \(profileText())
        Resumo:
        \(summaryText())
        Últimas falas:
        \(turns)
        Fala atual:
        \(user)
        Use só as custom tools. Ação destrutiva espera o Swift confirmar.
        """
    }

    func estimatedTokens(persona: String, draft: String) -> Int {
        max(1, prompt(persona: persona, user: draft).count / 4)
    }

    func saveProfile(_ text: String) -> ProfileWrite {
        guard let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else {
            TecloraLog.error("profile.json rejeitado: JSON inválido")
            return .invalidJSON
        }
        guard data.count <= 2048 else {
            TecloraLog.error("profile.json rejeitado: passou de 2 KB")
            return .tooLarge
        }
        do {
            try data.write(to: root.appendingPathComponent("profile.json"), options: .atomic)
            return .saved
        } catch {
            TecloraLog.error("profile.json não gravou")
            return .invalidJSON
        }
    }

    func record(user: String, pet: String) {
        var turns = loadTurns()
        turns.append(TecpetTurn(role: "user", text: user))
        turns.append(TecpetTurn(role: "pet", text: pet))
        if turns.count > 12 { turns = Array(turns.suffix(12)) }
        saveTurns(turns)
        var summary = summaryText()
        let line = "- \(user.prefix(90)) → \(pet.prefix(90))"
        summary = summary.isEmpty ? line : summary + "\n" + line
        if summary.count > 1500 { summary = String(summary.suffix(1500)) }
        try? summary.write(to: root.appendingPathComponent("summary.md"), atomically: true, encoding: .utf8)
        absorbFact(from: user)
    }

    private func absorbFact(from user: String) {
        let folded = AppSearch.fold(user)
        var profile = (try? JSONSerialization.jsonObject(with: Data(profileText().utf8))) as? [String: Any] ?? [:]
        if folded.hasPrefix("me chama de ") {
            let name = user.split(separator: " ", maxSplits: 3).last.map(String.init) ?? ""
            if !name.isEmpty { profile["name"] = name }
        }
        if let range = folded.range(of: "nao abre ") {
            let raw = String(folded[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            var never = profile["never"] as? [String] ?? []
            if !raw.isEmpty, !never.contains(raw) { never.append(raw) }
            profile["never"] = never
        }
        guard let data = try? JSONSerialization.data(withJSONObject: profile, options: [.prettyPrinted, .sortedKeys]),
              data.count <= 2048 else { return }
        try? data.write(to: root.appendingPathComponent("profile.json"), options: .atomic)
    }

    private func loadTurns() -> [TecpetTurn] {
        let url = root.appendingPathComponent("turns.jsonl")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").compactMap { line in
            try? JSONDecoder().decode(TecpetTurn.self, from: Data(line.utf8))
        }
    }

    private func saveTurns(_ turns: [TecpetTurn]) {
        let lines = turns.compactMap { turn -> String? in
            guard let data = try? JSONEncoder().encode(turn) else { return nil }
            return String(data: data, encoding: .utf8)
        }
        try? lines.joined(separator: "\n").write(
            to: root.appendingPathComponent("turns.jsonl"),
            atomically: true,
            encoding: .utf8
        )
    }
}
