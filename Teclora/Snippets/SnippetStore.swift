import Foundation
import Observation

struct Snippet: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var name: String
    var shortcut: String
    var body: String
    var createdAt: Date
}

/// Snippets em `Application Support/Teclora/snippets.json`. Não saem do Mac.
@MainActor
@Observable
final class SnippetStore {
    private(set) var snippets: [Snippet] = []
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        load()
    }

    func add(name: String, shortcut: String, body: String) {
        let snippet = Snippet(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            shortcut: shortcut.trimmingCharacters(in: .whitespacesAndNewlines),
            body: body,
            createdAt: Date()
        )
        guard !snippet.name.isEmpty, !snippet.body.isEmpty else { return }
        snippets.insert(snippet, at: 0)
        save()
        onChange?()
    }

    func update(_ snippet: Snippet) {
        guard let index = snippets.firstIndex(where: { $0.id == snippet.id }) else { return }
        snippets[index] = snippet
        save()
        onChange?()
    }

    func delete(_ id: UUID) {
        guard snippets.contains(where: { $0.id == id }) else { return }
        snippets.removeAll { $0.id == id }
        save()
        onChange?()
    }

    private var fileURL: URL? { AppSupport.file("snippets.json") }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            snippets = try Self.decoder.decode([Snippet].self, from: data)
        } catch {
            TecloraLog.error("Não leu os snippets")
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            try Self.encoder.encode(snippets).write(to: fileURL, options: .atomic)
        } catch {
            TecloraLog.error("Não gravou os snippets")
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
