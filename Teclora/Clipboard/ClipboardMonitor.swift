import AppKit

/// Olha `changeCount` num timer. Não observa o pasteboard a cada frame.
@MainActor
final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?

    init(store: ClipboardStore) {
        self.store = store
    }

    func start() {
        store.seedCurrentClipboard()
        store.syncChangeCount(NSPasteboard.general.changeCount)
        let timer = Timer(timeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.store.noteExternalChange()
            }
        }
        timer.tolerance = 0.2
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }
}
