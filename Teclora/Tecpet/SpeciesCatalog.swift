import AppKit

struct Species: Identifiable, Codable, Sendable, Equatable {
    let id: String
    let defaultName: String
    let art: String
    let vibe: String
}

private struct SpeciesFile: Codable {
    let species: [Species]
}

enum SpeciesCatalog {
    static let all: [Species] = load()

    static func species(id: String) -> Species? {
        all.first { $0.id == id } ?? all.first
    }

    static func portrait(for species: Species) -> NSImage? {
        let name = (species.art as NSString).deletingPathExtension
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Tecpet/Art"),
            Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Art"),
            Bundle.main.url(forResource: name, withExtension: "png"),
        ]
        for url in candidates.compactMap(\.self) {
            if let image = NSImage(contentsOf: url) { return image }
        }
        TecloraLog.error("Sem retrato da espécie \(species.id)")
        return nil
    }

    private static func load() -> [Species] {
        let url = Bundle.main.url(forResource: "species", withExtension: "json", subdirectory: "Tecpet")
            ?? Bundle.main.url(forResource: "species", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(SpeciesFile.self, from: data),
              !file.species.isEmpty else {
            TecloraLog.error("Não leu species.json")
            return []
        }
        return file.species
    }
}
