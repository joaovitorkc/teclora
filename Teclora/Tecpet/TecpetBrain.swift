import Foundation

/// Um turno: CreateAgent + Send + CloseAgent. A memória fica no Teclora, não no bridge.
@MainActor
final class TecpetBrain {
    private let bridge = CursorBridge()
    private let memory = TecpetMemory()
    private let clipboard: ClipboardStore
    private let history: LaunchHistory
    private var tools: CursorToolServer?
    private var callbackReady = false

    init(clipboard: ClipboardStore, history: LaunchHistory) {
        self.clipboard = clipboard
        self.history = history
    }

    var bridgeStatus: CursorBridgeDownload.Status { CursorBridgeDownload.status() }

    func prepare(apiKey: String) async throws -> BridgeReady {
        if CursorBridgeDownload.status() != .ready {
            let status = await CursorBridgeDownload.ensure()
            if status != .ready { throw CursorBridgeError.missing }
        }
        let ready = try await bridge.ensure(apiKey: apiKey)
        try await registerTools(ready)
        return ready
    }

    func speak(_ text: String, persona: String, apiKey: String, modelId: String) async -> String {
        do {
            let ready = try await prepare(apiKey: apiKey)
            let model = modelId.isEmpty ? "composer-2.5-fast" : modelId
            let sandbox = CursorLayout.sandbox()?.path ?? ""
            let created = try await CursorConnect.unary(
                base: ready.url,
                token: ready.token,
                service: "SdkAgentService",
                method: "CreateAgent",
                body: ["options": agentOptions(model: model, apiKey: apiKey, cwd: sandbox)]
            )
            let agentId = created["agentId"] as? String ?? ""
            let messages = try await CursorConnect.stream(
                base: ready.url,
                token: ready.token,
                service: "SdkAgentService",
                method: "Send",
                body: ["agentId": agentId, "message": ["text": prompt(persona: persona, user: text)]]
            )
            _ = try? await CursorConnect.unary(
                base: ready.url,
                token: ready.token,
                service: "SdkAgentService",
                method: "CloseAgent",
                body: ["agentId": agentId]
            )
            let answer = Self.assistantText(messages)
            memory.record(user: text, pet: answer)
            return answer.isEmpty ? "Não veio texto do Cursor." : answer
        } catch {
            TecloraLog.error("Turno do Tecpet falhou")
            return "O Cursor não respondeu agora. O pet continua aqui."
        }
    }

    func listModels(apiKey: String) async throws -> [String] {
        let ready = try await prepare(apiKey: apiKey)
        let response = try await CursorConnect.unary(
            base: ready.url,
            token: ready.token,
            service: "SdkCursorService",
            method: "ListModels",
            body: ["options": ["apiKey": apiKey]]
        )
        let items = response["items"] as? [[String: Any]] ?? []
        return items.compactMap { $0["id"] as? String }
    }

    func me(apiKey: String) async throws -> String {
        let ready = try await prepare(apiKey: apiKey)
        let response = try await CursorConnect.unary(
            base: ready.url,
            token: ready.token,
            service: "SdkCursorService",
            method: "Me",
            body: ["options": ["apiKey": apiKey]]
        )
        let user = response["user"] as? [String: Any] ?? [:]
        return (user["userEmail"] as? String) ?? "conta ok"
    }

    private func registerTools(_ ready: BridgeReady) async throws {
        if tools == nil {
            tools = CursorToolServer { [clipboard, history] name, args in
                TecpetTools.run(name, args, clipboard: clipboard, history: history)
            }
        }
        guard !callbackReady, let tools else { return }
        let url = try await tools.start()
        _ = try await CursorConnect.unary(
            base: ready.url,
            token: ready.token,
            service: "SdkBridgeControlService",
            method: "SetToolCallback",
            body: ["url": url.absoluteString, "authToken": tools.token]
        )
        callbackReady = true
    }

    private func agentOptions(model: String, apiKey: String, cwd: String) -> [String: Any] {
        [
            "apiKey": apiKey,
            "model": ["id": model],
            "tools": ["names": [String]()],
            "local": [
                "cwd": [cwd],
                "sandboxOptions": ["enabled": true],
                "autoReview": false,
                "customTools": TecpetTools.definitions(),
            ],
        ]
    }

    private func prompt(persona: String, user: String) -> String {
        let turns = memory.recentTurns().map { "\($0.role): \($0.text)" }.joined(separator: "\n")
        return """
        \(persona)
        Perfil:
        \(memory.profileText())
        Resumo:
        \(memory.summaryText())
        Últimas falas:
        \(turns)
        Fala atual:
        \(user)
        Use só as custom tools. Ação destrutiva espera o Swift confirmar.
        """
    }

    private static func assistantText(_ messages: [[String: Any]]) -> String {
        var text = ""
        for message in messages {
            if let result = message["result"] as? [String: Any] {
                if let inner = result["result"] as? [String: Any],
                   let value = inner["result"] as? String, !value.isEmpty {
                    text = value
                } else if let value = result["result"] as? String, !value.isEmpty {
                    text = value
                }
            }
        }
        return text
    }
}
