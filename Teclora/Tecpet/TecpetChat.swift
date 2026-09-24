import AppKit
import SwiftUI

struct ChatLine: Identifiable, Equatable {
    let id = UUID()
    let fromPet: Bool
    let text: String
}

/// Conversa da sessão, sem modelo. "abrir …" reusa o router dos apps.
@MainActor
final class TecpetChatController {
    private let store: TecpetStore
    private let history: LaunchHistory
    private let clipboard: ClipboardStore
    private let model = TecpetChatModel()
    private var panel: NSPanel?
    private var keyMonitor: Any?

    init(store: TecpetStore, history: LaunchHistory, clipboard: ClipboardStore) {
        self.store = store
        self.history = history
        self.clipboard = clipboard
    }

    func open() {
        let panel = panel ?? makePanel()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        model.focus += 1
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let host = NSHostingController(rootView: TecpetChatView(model: model, onSubmit: { [weak self] in
            self?.submit()
        }))
        let panel = NSPanel(contentViewController: host)
        panel.title = store.wakeName.isEmpty ? "Tecpet" : store.wakeName
        panel.styleMask = [.titled, .closable]
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.setContentSize(NSSize(width: 320, height: 360))
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let swallow = MainActor.assumeIsolated { () -> Bool in
                guard let self, event.window === self.panel, event.keyCode == 53 else { return false }
                self.close()
                return true
            }
            return swallow ? nil : event
        }
        return panel
    }

    private func submit() {
        let text = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        model.lines.append(ChatLine(fromPet: false, text: text))
        model.draft = ""
        if openApp(named: text) {
            model.lines.append(ChatLine(fromPet: true, text: "Abri."))
        } else {
            model.lines.append(ChatLine(
                fromPet: true,
                text: "Liga o Cursor em Preferências para eu pensar de verdade."
            ))
        }
    }

    private func openApp(named text: String) -> Bool {
        let folded = AppSearch.fold(text)
        guard folded.hasPrefix("abrir ") else { return false }
        let name = AppSearch.fold(String(folded.dropFirst("abrir ".count)))
        guard !name.isEmpty else { return false }
        let apps = AppCatalog.load(excluding: Bundle.main.bundleIdentifier)
        let match = apps
            .compactMap { app -> (Int, InstalledApp)? in
                let keys = [app.name, app.fileName].map(AppSearch.fold)
                guard let rank = keys.compactMap({ AppSearch.matchRank(name: $0, query: name) }).min() else { return nil }
                return (rank, app)
            }
            .min { $0.0 < $1.0 }?
            .1
        guard let match else { return false }
        ConfirmRouter.perform(
            item: LauncherItem.application(match, section: "Aplicativos"),
            alternate: false,
            history: history,
            clipboard: clipboard,
            closeLauncher: { _ in },
            showSettings: { _ in }
        )
        return true
    }
}

@MainActor
@Observable
final class TecpetChatModel {
    var lines: [ChatLine] = [
        ChatLine(fromPet: true, text: "Liga o Cursor em Preferências para eu pensar de verdade."),
    ]
    var draft = ""
    var focus = 0
}

private struct TecpetChatView: View {
    @Bindable var model: TecpetChatModel
    let onSubmit: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(model.lines) { line in
                        Text(line.text)
                            .font(.system(size: 13))
                            .padding(8)
                            .background(line.fromPet ? Color.primary.opacity(0.08) : Color.accentColor.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, alignment: line.fromPet ? .leading : .trailing)
                    }
                }
                .padding(12)
            }
            TextField("Falar com o pet", text: $model.draft)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(onSubmit)
                .padding([.horizontal, .bottom], 12)
        }
        .onChange(of: model.focus) { focused = true }
        .onAppear { focused = true }
    }
}
