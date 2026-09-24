import Foundation

/// `~/Library/Application Support/Teclora/`. JSON local; nada vai para a rede.
enum AppSupport {
    static func directory() -> URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            TecloraLog.error("Application Support indisponível")
            return nil
        }
        let directory = base.appendingPathComponent("Teclora", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            TecloraLog.error("Não criou Application Support/Teclora")
            return nil
        }
    }

    static func file(_ name: String) -> URL? {
        directory()?.appendingPathComponent(name)
    }
}
