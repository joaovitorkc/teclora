import Foundation
import Network

/// HTTP/1.1 em loopback para `CallCustomTool`. O resultado é sempre um objeto JSON.
@MainActor
final class CursorToolServer {
    let token = UUID().uuidString
    private(set) var url: URL?
    private var listener: NWListener?
    private var startContinuation: CheckedContinuation<URL, Error>?
    private let execute: @MainActor (String, [String: Any]) -> [String: Any]

    init(execute: @escaping @MainActor (String, [String: Any]) -> [String: Any]) {
        self.execute = execute
    }

    func start() async throws -> URL {
        if let url { return url }
        let listener = try NWListener(using: .tcp, on: .any)
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: .main)
            Task { @MainActor in
                self?.read(connection, buffer: Data())
            }
        }
        self.listener = listener
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            self.startContinuation = continuation
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in
                    self?.handleListener(state)
                }
            }
            listener.start(queue: .main)
        }
    }

    private func handleListener(_ state: NWListener.State) {
        guard let continuation = startContinuation else { return }
        switch state {
        case .ready:
            let port = listener?.port?.rawValue ?? 0
            let url = URL(string: "http://127.0.0.1:\(port)")!
            self.url = url
            startContinuation = nil
            continuation.resume(returning: url)
        case .failed:
            startContinuation = nil
            continuation.resume(throwing: CursorBridgeError.spawn)
        default:
            break
        }
    }

    private func read(_ connection: NWConnection, buffer: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, complete, _ in
            MainActor.assumeIsolated {
            guard let self else { return }
            var next = buffer
            if let data { next.append(data) }
            if let response = self.response(for: next) {
                connection.send(content: response, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }
            if complete {
                connection.cancel()
                return
            }
            self.read(connection, buffer: next)
            }
        }
    }

    private func response(for data: Data) -> Data? {
        guard let text = String(data: data, encoding: .utf8), text.contains("\r\n\r\n") else { return nil }
        let parts = text.components(separatedBy: "\r\n\r\n")
        let head = parts[0]
        var bodyText = parts.dropFirst().joined(separator: "\r\n\r\n")
        if head.lowercased().contains("transfer-encoding: chunked") {
            guard let decoded = Self.chunks(bodyText) else { return nil }
            bodyText = decoded
        } else if let length = Self.contentLength(head), bodyText.utf8.count < length {
            return nil
        }
        let authorized = head.split(separator: "\r\n").contains { line in
            let parts = line.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { return false }
            let name = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            return name == "authorization" && value == "Bearer \(token)"
        }
        var result: [String: Any] = ["ok": false, "error": "unauthorized"]
        if authorized,
           let body = bodyText.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
            let name = object["toolName"] as? String ?? ""
            let args = object["args"] as? [String: Any] ?? [:]
            result = execute(name, args)
        }
        let payload = (try? JSONSerialization.data(withJSONObject: ["result": result])) ?? Data("{}".utf8)
        let header = "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(payload.count)\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(payload)
        return response
    }

    private static func contentLength(_ head: String) -> Int? {
        for line in head.split(separator: "\r\n") where line.lowercased().hasPrefix("content-length:") {
            return Int(line.split(separator: ":").last?.trimmingCharacters(in: .whitespaces) ?? "")
        }
        return nil
    }

    private static func chunks(_ body: String) -> String? {
        var rest = body
        var out = ""
        while !rest.isEmpty {
            guard let newline = rest.range(of: "\r\n") else { return nil }
            let sizeText = rest[..<newline.lowerBound]
            guard let size = Int(sizeText.trimmingCharacters(in: .whitespaces), radix: 16) else { return nil }
            if size == 0 { return out }
            let start = newline.upperBound
            guard rest.distance(from: start, to: rest.endIndex) >= size else { return nil }
            let end = rest.index(start, offsetBy: size)
            out += rest[start..<end]
            rest = String(rest[end...])
            if rest.hasPrefix("\r\n") { rest.removeFirst(2) }
        }
        return nil
    }
}
