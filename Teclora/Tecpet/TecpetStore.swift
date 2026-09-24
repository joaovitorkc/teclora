import Foundation
import Observation

enum PetCorner: String, Codable, CaseIterable, Identifiable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .topLeading: "Superior esquerdo"
        case .topTrailing: "Superior direito"
        case .bottomLeading: "Inferior esquerdo"
        case .bottomTrailing: "Inferior direito"
        }
    }
}

enum PetMenuStyle: String, Codable, CaseIterable, Identifiable {
    case icon
    case pet
    case both

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon: "Ícone Teclora"
        case .pet: "Retrato do pet"
        case .both: "Os dois"
        }
    }
}

private struct TecpetState: Codable, Equatable {
    var speciesId: String
    var wakeName: String
    var respondToWake: Bool
    var corner: PetCorner
    var menuStyle: PetMenuStyle
    var muted: Bool
    var hidden: Bool
}

/// Estado da casca em `Application Support/Teclora/tecpet/state.json`. Sem rede.
@MainActor
@Observable
final class TecpetStore {
    private(set) var speciesId: String
    private(set) var wakeName: String
    private(set) var respondToWake: Bool
    private(set) var corner: PetCorner
    private(set) var menuStyle: PetMenuStyle
    private(set) var muted: Bool
    private(set) var hidden: Bool
    @ObservationIgnored var onChange: (() -> Void)?

    init() {
        let state = Self.load()
        speciesId = state.speciesId
        wakeName = state.wakeName
        respondToWake = state.respondToWake
        corner = state.corner
        menuStyle = state.menuStyle
        muted = state.muted
        hidden = state.hidden
    }

    var species: Species? { SpeciesCatalog.species(id: speciesId) }

    func selectSpecies(_ id: String) {
        guard let next = SpeciesCatalog.species(id: id), next.id != speciesId else { return }
        let previousName = species?.defaultName
        speciesId = next.id
        if wakeName == previousName { wakeName = next.defaultName }
        commit()
    }

    func setWakeName(_ name: String) {
        wakeName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        commit()
    }

    func setRespondToWake(_ value: Bool) {
        respondToWake = value
        commit()
    }

    func setCorner(_ value: PetCorner) {
        corner = value
        commit()
    }

    func setMenuStyle(_ value: PetMenuStyle) {
        menuStyle = value
        commit()
    }

    func setMuted(_ value: Bool) {
        muted = value
        commit()
    }

    func setHidden(_ value: Bool) {
        hidden = value
        commit()
    }

    /// Nome completo digitado no launcher, com o toggle ligado e o pet em som.
    func consumesWake(_ query: String) -> Bool {
        guard respondToWake, !muted else { return false }
        let wake = AppSearch.fold(wakeName)
        guard !wake.isEmpty else { return false }
        return AppSearch.fold(query) == wake
    }

    private func commit() {
        save()
        onChange?()
    }

    private var fileURL: URL? { Self.stateURL(create: true) }

    private static func stateURL(create: Bool) -> URL? {
        guard let root = AppSupport.directory()?.appendingPathComponent("tecpet", isDirectory: true) else { return nil }
        if create {
            try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root.appendingPathComponent("state.json")
    }

    private static func load() -> TecpetState {
        let fallback = SpeciesCatalog.all.first
        let standard = TecpetState(
            speciesId: fallback?.id ?? "pipoca",
            wakeName: fallback?.defaultName ?? "Pipoca",
            respondToWake: false,
            corner: .bottomTrailing,
            menuStyle: .icon,
            muted: false,
            hidden: false
        )
        guard let url = stateURL(create: false),
              let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(TecpetState.self, from: data) else { return standard }
        return state
    }

    private func save() {
        guard let fileURL else { return }
        let state = TecpetState(
            speciesId: speciesId,
            wakeName: wakeName,
            respondToWake: respondToWake,
            corner: corner,
            menuStyle: menuStyle,
            muted: muted,
            hidden: hidden
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(state).write(to: fileURL, options: .atomic)
        } catch {
            TecloraLog.error("Não gravou o estado do Tecpet")
        }
    }
}
