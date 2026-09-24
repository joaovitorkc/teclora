import CryptoKit
import Foundation

enum CursorBridgeDownload {
    enum Status: Equatable {
        case missing
        case ready
        case failed(String)
    }

    static func status() -> Status {
        guard let binary = CursorLayout.binary(),
              FileManager.default.isExecutableFile(atPath: binary.path) else { return .missing }
        return .ready
    }

    /// Baixa o tar.gz, confere o SHA-256 e extrai. Hash errado apaga e recusa.
    static func ensure() async -> Status {
        if status() == .ready { return .ready }
        guard let dest = CursorLayout.bridgeDirectory() else { return .failed("Sem pasta do bridge") }
        let archive = dest.appendingPathComponent("cursor-sdk-bridge.tar.gz")
        do {
            let (file, _) = try await URLSession.shared.download(from: CursorLayout.archive)
            try? FileManager.default.removeItem(at: archive)
            try FileManager.default.moveItem(at: file, to: archive)
            let digest = SHA256.hash(data: try Data(contentsOf: archive)).hex
            guard digest == CursorLayout.sha256 else {
                try? FileManager.default.removeItem(at: archive)
                TecloraLog.error("Hash do bridge não confere")
                return .failed("Hash não confere")
            }
            let tar = Process()
            tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tar.arguments = ["-xzf", archive.path, "-C", dest.path]
            try tar.run()
            tar.waitUntilExit()
            try? FileManager.default.removeItem(at: archive)
            guard tar.terminationStatus == 0, status() == .ready else {
                TecloraLog.error("Não extraiu o bridge")
                return .failed("Extração falhou")
            }
            return .ready
        } catch {
            try? FileManager.default.removeItem(at: archive)
            TecloraLog.error("Download do bridge falhou")
            return .failed("Download falhou")
        }
    }
}

private extension SHA256.Digest {
    var hex: String { map { String(format: "%02x", $0) }.joined() }
}
