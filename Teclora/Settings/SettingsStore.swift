import Foundation
import Observation

struct TecloraSettings: Codable, Equatable, Sendable {
    var recordClipboard: Bool
    var clipboardLimit: Int

    static let limitChoices = [25, 50, 100, 200]
    static let standard = TecloraSettings(recordClipboard: true, clipboardLimit: 50)
}

/// Preferências em `Application Support/Teclora/settings.json`.
@MainActor
@Observable
final class SettingsStore {
    private(set) var recordClipboard: Bool
    private(set) var clipboardLimit: Int
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        let loaded = Self.load()
        recordClipboard = loaded.recordClipboard
        clipboardLimit = loaded.clipboardLimit
    }

    func setRecordClipboard(_ value: Bool) {
        guard recordClipboard != value else { return }
        recordClipboard = value
        save()
        onChange?()
    }

    func setClipboardLimit(_ value: Int) {
        let choice = TecloraSettings.limitChoices.contains(value) ? value : TecloraSettings.standard.clipboardLimit
        guard clipboardLimit != choice else { return }
        clipboardLimit = choice
        save()
        onChange?()
    }

    private var snapshot: TecloraSettings {
        TecloraSettings(recordClipboard: recordClipboard, clipboardLimit: clipboardLimit)
    }

    private static func load() -> TecloraSettings {
        guard let url = AppSupport.file("settings.json"),
              FileManager.default.fileExists(atPath: url.path) else {
            return .standard
        }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(TecloraSettings.self, from: data)
            let limit = TecloraSettings.limitChoices.contains(decoded.clipboardLimit)
                ? decoded.clipboardLimit
                : TecloraSettings.standard.clipboardLimit
            return TecloraSettings(recordClipboard: decoded.recordClipboard, clipboardLimit: limit)
        } catch {
            TecloraLog.error("Não leu as preferências")
            return .standard
        }
    }

    private func save() {
        guard let url = AppSupport.file("settings.json") else { return }
        do {
            let data = try JSONEncoder.pretty.encode(snapshot)
            try data.write(to: url, options: .atomic)
        } catch {
            TecloraLog.error("Não gravou as preferências")
        }
    }
}

private extension JSONEncoder {
    static let pretty: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}
