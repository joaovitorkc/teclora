import AppKit

/// Liga overlay, chat e o ícone da barra. A busca do launcher fica de fora.
@MainActor
final class TecpetModule {
    let store: TecpetStore
    let provider: TecpetProvider
    private let overlay: TecpetOverlayController
    private let chat: TecpetChatController
    private weak var status: StatusItemController?

    init(store: TecpetStore, history: LaunchHistory, clipboard: ClipboardStore, showSettings: @escaping () -> Void) {
        self.store = store
        provider = TecpetProvider(store: store)
        chat = TecpetChatController(store: store, history: history, clipboard: clipboard)
        overlay = TecpetOverlayController(
            store: store,
            onOpenChat: { [chat] in chat.open() },
            onSettings: showSettings
        )
        store.onChange = { [weak self] in self?.refresh() }
    }

    func attach(status: StatusItemController) {
        self.status = status
        refresh()
    }

    func openChat() {
        chat.open()
    }

    private func refresh() {
        overlay.refresh()
        let portrait = store.species.flatMap(SpeciesCatalog.portrait)
        status?.applyPet(style: store.menuStyle, portrait: portrait)
    }
}
