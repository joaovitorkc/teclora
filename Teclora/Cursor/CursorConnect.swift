import Foundation

/// Connect JSON em HTTP/1.1. Unary é JSON; `Send` é stream com envelope.
enum CursorConnect {
    static func unary(
        base: URL,
        token: String,
        service: String,
        method: String,
        body: [String: Any]
    ) async throws -> [String: Any] {
        let data = try await send(base: base, token: token, service: service, method: method, body: body, stream: false)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object ?? [:]
    }

    static func stream(
        base: URL,
        token: String,
        service: String,
        method: String,
        body: [String: Any]
    ) async throws -> [[String: Any]] {
        let data = try await send(base: base, token: token, service: service, method: method, body: body, stream: true)
        return parseEnvelopes(data)
    }

    private static func send(
        base: URL,
        token: String,
        service: String,
        method: String,
        body: [String: Any],
        stream: Bool
    ) async throws -> Data {
        let url = base.appendingPathComponent("sdk.v1.\(service)/\(method)")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "Connect-Protocol-Version")
        request.setValue(stream ? "application/connect+json" : "application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            TecloraLog.error("RPC \(method) falhou")
            throw CursorBridgeError.rpc(method)
        }
        return data
    }

    /// Envelope Connect: 1 byte de flags + 4 bytes de tamanho + JSON.
    static func parseEnvelopes(_ data: Data) -> [[String: Any]] {
        var messages: [[String: Any]] = []
        var offset = 0
        while offset + 5 <= data.count {
            let flags = data[offset]
            let length = data.subdata(in: (offset + 1)..<(offset + 5)).withUnsafeBytes {
                Int(UInt32(bigEndian: $0.load(as: UInt32.self)))
            }
            offset += 5
            guard length >= 0, offset + length <= data.count else { break }
            let payload = data.subdata(in: offset..<(offset + length))
            offset += length
            if flags & 0x02 != 0 { break }
            if let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any] {
                messages.append(object)
            }
        }
        if messages.isEmpty, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            messages.append(object)
        }
        return messages
    }
}

enum CursorBridgeError: Error {
    case spawn
    case handshake
    case rpc(String)
    case missing
}
