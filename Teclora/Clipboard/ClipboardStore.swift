import AppKit
import Observation

struct ClipboardEntry: Codable, Identifiable, Sendable, Equatable {
    var id: UUID
    var text: String
    var createdAt: Date
    var pinned: Bool
}

/// Histórico de texto no disco. Não lê imagem e não fala com a rede.
@MainActor
@Observable
final class ClipboardStore {
    private(set) var entries: [ClipboardEntry] = []
    private let settings: SettingsStore
    private var lastChangeCount: Int
    @ObservationIgnored var onChange: (() -> Void)?

    init(settings: SettingsStore) {
        self.settings = settings
        lastChangeCount = NSPasteboard.general.changeCount
        load()
    }

    func syncChangeCount(_ count: Int) {
        lastChangeCount = count
    }

    /// Chamado pelo timer. Ignora o nosso próprio `copyBack`.
    func noteExternalChange() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count
        guard settings.recordClipboard else { return }
        guard let text = board.string(forType: .string) else { return }
        ingest(text)
    }

    /// Na abertura: guarda o texto atual se ainda não estiver no histórico.
    func seedCurrentClipboard() {
        guard settings.recordClipboard else { return }
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        guard !entries.contains(where: { $0.text == text }) else { return }
        ingest(text)
    }

    func copyBack(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        var entry = entries.remove(at: index)
        entry.createdAt = Date()
        entries.append(entry)
        sort()
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(entry.text, forType: .string)
        lastChangeCount = board.changeCount
        save()
        onChange?()
    }

    func togglePin(_ id: UUID) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[index].pinned.toggle()
        sort()
        save()
        onChange?()
    }

    func delete(_ id: UUID) {
        guard entries.contains(where: { $0.id == id }) else { return }
        entries.removeAll { $0.id == id }
        save()
        onChange?()
    }

    func applyLimit() {
        let before = entries.count
        trim()
        guard entries.count != before else { return }
        save()
        onChange?()
    }

    private func ingest(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        if let index = entries.firstIndex(where: { $0.text == cleaned }) {
            var entry = entries.remove(at: index)
            entry.createdAt = Date()
            entries.append(entry)
        } else {
            entries.append(
                ClipboardEntry(id: UUID(), text: cleaned, createdAt: Date(), pinned: false)
            )
        }
        sort()
        trim()
        save()
        onChange?()
    }

    private func sort() {
        entries.sort { lhs, rhs in
            if lhs.pinned != rhs.pinned { return lhs.pinned && !rhs.pinned }
            return lhs.createdAt > rhs.createdAt
        }
    }

    private func trim() {
        let limit = max(1, settings.clipboardLimit)
        let pinned = entries.filter(\.pinned)
        let rest = entries.filter { !$0.pinned }
        let room = max(0, limit - pinned.count)
        entries = pinned + Array(rest.prefix(room))
    }

    private var fileURL: URL? {
        AppSupport.file("clipboard.json")
    }

    private func load() {
        guard let fileURL, FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try Self.decoder.decode([ClipboardEntry].self, from: data)
            entries = decoded
            sort()
            trim()
        } catch {
            TecloraLog.error("Não leu o histórico de clipboard")
        }
    }

    private func save() {
        guard let fileURL else { return }
        do {
            let data = try Self.encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            TecloraLog.error("Não gravou o histórico de clipboard")
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
