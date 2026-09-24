import Foundation
import Observation

struct Quicklink: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var name: String
    var target: String
}

/// Atalhos locais (URL ou caminho) em `quicklinks.json`.
@MainActor
@Observable
final class QuicklinkStore {
    private(set) var links: [Quicklink] = []
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        load()
    }

    func add(name: String, target: String) {
        let link = Quicklink(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            target: target.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        guard !link.name.isEmpty, !link.target.isEmpty else { return }
        links.append(link)
        save()
        onChange?()
    }

    func update(_ link: Quicklink) {
        guard let index = links.firstIndex(where: { $0.id == link.id }) else { return }
        links[index] = link
        save()
        onChange?()
    }

    func delete(_ id: UUID) {
        guard links.contains(where: { $0.id == id }) else { return }
        links.removeAll { $0.id == id }
        save()
        onChange?()
    }

    private var fileURL: URL? { AppSupport.file("quicklinks.json") }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            links = try JSONDecoder().decode([Quicklink].self, from: Data(contentsOf: fileURL))
        } catch {
            TecloraLog.error("Não leu os quicklinks")
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(links)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            TecloraLog.error("Não gravou os quicklinks")
        }
    }
}
