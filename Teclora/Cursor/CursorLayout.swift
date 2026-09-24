import Foundation

enum CursorLayout {
    static let version = "v1.0.28"
    static let sha256 = "52ebfdab4e7806270122bea6c8f972646516297343c483e6700b37d444515af5"
    static let archive = URL(string: "https://github.com/cursor/sdk-bridge/releases/download/v1.0.28/cursor-sdk-bridge-standalone-darwin-arm64.tar.gz")!

    static func tecpetDirectory() -> URL? {
        guard let root = AppSupport.directory()?.appendingPathComponent("tecpet", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func bridgeDirectory() -> URL? {
        guard let root = AppSupport.directory()?
            .appendingPathComponent("bridge", isDirectory: true)
            .appendingPathComponent(version, isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func binary() -> URL? {
        bridgeDirectory()?.appendingPathComponent("bin/cursor-sdk-bridge")
    }

    static func sandbox() -> URL? {
        guard let dir = tecpetDirectory()?.appendingPathComponent("sandbox", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func cursorJSON() -> URL? {
        tecpetDirectory()?.appendingPathComponent("cursor.json")
    }

    static func stateRoot() -> URL? {
        guard let dir = AppSupport.directory()?
            .appendingPathComponent("bridge/state", isDirectory: true) else { return nil }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

struct CursorModelFile: Codable {
    var modelId: String
}

enum CursorModelStore {
    static func load() -> String {
        guard let url = CursorLayout.cursorJSON(),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(CursorModelFile.self, from: data) else { return "" }
        return file.modelId
    }

    static func save(_ modelId: String) {
        guard let url = CursorLayout.cursorJSON() else { return }
        let data = try? JSONEncoder().encode(CursorModelFile(modelId: modelId))
        try? data?.write(to: url, options: .atomic)
    }
}
