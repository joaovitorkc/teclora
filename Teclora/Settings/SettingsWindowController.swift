import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private let model: SettingsModel
    private var window: NSWindow?

    init(
        settings: SettingsStore,
        clipboard: ClipboardStore,
        snippets: SnippetStore,
        quicklinks: QuicklinkStore,
        tecpet: TecpetStore,
        brain: TecpetBrain
    ) {
        model = SettingsModel(
            settings: settings,
            clipboard: clipboard,
            snippets: snippets,
            quicklinks: quicklinks,
            tecpet: tecpet,
            brain: brain
        )
    }

    func show(_ tab: SettingsTab = .general) {
        model.selectedTab = tab
        present()
    }

    func noteDataChange() {
        model.noteChange()
    }

    private func present() {
        let window = window ?? makeWindow()
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let host = NSHostingController(rootView: SettingsView(model: model))
        let window = NSWindow(contentViewController: host)
        window.title = "Preferências"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 520, height: 520))
        return window
    }
}
