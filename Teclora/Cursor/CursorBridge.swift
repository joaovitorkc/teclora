import Foundation

struct BridgeReady: Sendable {
    let url: URL
    let token: String
}

/// Sobe o bridge em 127.0.0.1 e lê a ready-line. Não grava o token no log.
@MainActor
final class CursorBridge {
    private var process: Process?
    private var ready: BridgeReady?
    private var stderrTask: Task<Void, Never>?

    func ensure(apiKey: String) async throws -> BridgeReady {
        if let ready, process?.isRunning == true { return ready }
        guard CursorBridgeDownload.status() == .ready,
              let binary = CursorLayout.binary(),
              let sandbox = CursorLayout.sandbox(),
              let state = CursorLayout.stateRoot() else {
            throw CursorBridgeError.missing
        }
        let pipe = Pipe()
        let process = Process()
        process.executableURL = binary
        process.arguments = [
            "--host", "127.0.0.1",
            "--port", "0",
            "--workspace", sandbox.path,
            "--state-root", state.path,
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["CURSOR_API_KEY"] = apiKey
        environment["CURSOR_SDK_CLIENT_LANGUAGE"] = "swift"
        process.environment = environment
        process.standardError = pipe
        process.standardOutput = Pipe()
        do { try process.run() } catch {
            TecloraLog.error("Não subiu o bridge")
            throw CursorBridgeError.spawn
        }
        self.process = process
        let handle = pipe.fileHandleForReading
        let parsed = try await Self.readReady(handle)
        ready = parsed
        stderrTask = Task.detached {
            _ = try? handle.readToEnd()
        }
        do {
            _ = try await CursorConnect.unary(
                base: parsed.url,
                token: parsed.token,
                service: "SdkBridgeControlService",
                method: "Ping",
                body: [:]
            )
        } catch {
            shutdown()
            throw CursorBridgeError.handshake
        }
        TecloraLog.info("Bridge pronto")
        return parsed
    }

    func shutdown() {
        process?.terminate()
        process = nil
        ready = nil
    }

    private static func readReady(_ handle: FileHandle) async throws -> BridgeReady {
        let prefix = "cursor-sdk-bridge ready "
        let deadline = Date().addingTimeInterval(30)
        var buffer = Data()
        while Date() < deadline {
            let chunk = handle.availableData
            if chunk.isEmpty {
                try await Task.sleep(nanoseconds: 50_000_000)
                continue
            }
            buffer.append(chunk)
            guard let text = String(data: buffer, encoding: .utf8) else { continue }
            for line in text.split(whereSeparator: \.isNewline) {
                guard line.hasPrefix(prefix) else { continue }
                let json = String(line.dropFirst(prefix.count))
                guard let data = json.data(using: .utf8),
                      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      (object["schemaVersion"] as? Int) == 1,
                      (object["transport"] as? String) == "tcp",
                      (object["protocol"] as? String) == "connect",
                      let urlString = object["url"] as? String,
                      let url = URL(string: urlString),
                      url.host == "127.0.0.1" || url.host == "localhost",
                      let tokenFile = object["authTokenFile"] as? String,
                      let token = try? String(contentsOfFile: tokenFile, encoding: .utf8)
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                      !token.isEmpty else {
                    throw CursorBridgeError.handshake
                }
                return BridgeReady(url: url, token: token)
            }
        }
        throw CursorBridgeError.handshake
    }
}
