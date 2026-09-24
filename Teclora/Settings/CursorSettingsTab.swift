import SwiftUI

@MainActor
@Observable
final class CursorSettingsModel {
    var keyDraft = ""
    var models: [String] = []
    var modelId = CursorModelStore.load()
    var account = ""
    var bridge = "ainda não baixado"
    var busy = false
    private let brain: TecpetBrain

    init(brain: TecpetBrain) {
        self.brain = brain
        refreshBridge()
    }

    func refreshBridge() {
        switch brain.bridgeStatus {
        case .missing: bridge = "ainda não baixado"
        case .ready: bridge = "baixado, hash ok"
        case .failed(let reason): bridge = reason
        }
    }

    func test() {
        let typed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { _ = CursorKeychain.save(typed) }
        guard let key = CursorKeychain.load() else {
            account = "sem chave"
            return
        }
        busy = true
        Task {
            do {
                account = try await brain.me(apiKey: key)
                models = try await brain.listModels(apiKey: key)
                if modelId.isEmpty || !models.contains(modelId) {
                    modelId = models.first { $0.contains("fast") } ?? models.first ?? ""
                    CursorModelStore.save(modelId)
                }
                refreshBridge()
            } catch {
                account = "não conectou"
                TecloraLog.error("Me/ListModels falhou")
                refreshBridge()
            }
            busy = false
            keyDraft = ""
        }
    }

    func selectModel(_ id: String) {
        modelId = id
        CursorModelStore.save(id)
    }
}

struct CursorSettingsTab: View {
    @Bindable var model: CursorSettingsModel

    var body: some View {
        Form {
            SecureField("API key do Cursor", text: $model.keyDraft)
            Button(model.busy ? "Testando…" : "Testar (Me)") { model.test() }
                .disabled(model.busy)
            if !model.account.isEmpty {
                Text(model.account).font(.callout).foregroundStyle(.secondary)
            }
            if !model.models.isEmpty {
                Picker("Modelo", selection: Binding(get: { model.modelId }, set: { model.selectModel($0) })) {
                    ForEach(model.models, id: \.self) { Text($0).tag($0) }
                }
            }
            LabeledContent("Bridge") { Text(model.bridge) }
            Text("GPT — em breve")
            Text("Claude — em breve")
        }
        .formStyle(.grouped)
        .padding(12)
        .onAppear {
            model.refreshBridge()
            if CursorKeychain.load() != nil, model.models.isEmpty { model.test() }
        }
    }
}
