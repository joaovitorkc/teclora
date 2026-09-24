import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: LauncherPanelController?
    private var hotkeys: HotkeyCenter?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var clipboardMonitor: ClipboardMonitor?
    private var tecpetModule: TecpetModule?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startLauncher()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return false
    }

    func startLauncher() {
        if panelController == nil {
            wire()
            return
        }
        panelController?.show()
    }

    private func wire() {
        let settings = SettingsStore()
        let clipboard = ClipboardStore(settings: settings)
        let snippets = SnippetStore()
        let quicklinks = QuicklinkStore()
        let files = FileProvider()
        let history = LaunchHistory()
        let tecpetStore = TecpetStore()
        let settingsWindow = SettingsWindowController(
            settings: settings,
            clipboard: clipboard,
            snippets: snippets,
            quicklinks: quicklinks,
            tecpet: tecpetStore
        )
        let tecpet = TecpetModule(
            store: tecpetStore,
            history: history,
            clipboard: clipboard,
            showSettings: { settingsWindow.show(.tecpet) }
        )
        let model = LauncherModel(
            history: history,
            providers: [
                ClipboardProvider(store: clipboard),
                SnippetProvider(store: snippets),
                QuicklinkProvider(store: quicklinks),
                files,
                WindowProvider(),
                CalcProvider(),
                LocalSystemProvider(),
                SystemCommandProvider(),
                tecpet.provider,
            ]
        )
        let panel = LauncherPanelController(model: model)

        panel.onPerform = { [weak panel] item, alternate in
            guard let panel else { return }
            if case .openTecpet = item.action {
                panel.hide(restorePrevious: false)
                tecpet.openChat()
                return
            }
            ConfirmRouter.perform(
                item: item,
                alternate: alternate,
                history: history,
                clipboard: clipboard,
                closeLauncher: { panel.hide(restorePrevious: $0) },
                showSettings: { settingsWindow.show($0) }
            )
        }
        panel.onDeleteClipboard = { id in
            ConfirmRouter.deleteClipboard(id, clipboard: clipboard)
        }
        let refresh: () -> Void = { [weak model] in
            model?.refreshHits()
            settingsWindow.noteDataChange()
        }
        clipboard.onChange = refresh
        snippets.onChange = refresh
        quicklinks.onChange = refresh
        files.onChange = { [weak model] in model?.refreshHits() }
        model.onRecomputed = { [weak model, weak panel] in
            guard let model, tecpet.store.consumesWake(model.query) else { return }
            model.query = ""
            panel?.hide(restorePrevious: false)
            tecpet.openChat()
        }
        settings.onChange = { [weak model] in
            clipboard.applyLimit()
            model?.refreshHits()
            settingsWindow.noteDataChange()
        }

        let monitor = ClipboardMonitor(store: clipboard)
        monitor.start()

        panelController = panel
        tecpetModule = tecpet
        self.settingsWindow = settingsWindow
        clipboardMonitor = monitor
        statusItem = StatusItemController(
            onToggle: { [weak panel] in panel?.toggle() },
            onOpen: { [weak panel] in panel?.show() },
            onSettings: { settingsWindow.show(.general) },
            onQuit: { NSApp.terminate(nil) }
        )
        if let statusItem {
            tecpet.attach(status: statusItem)
        }
        hotkeys = HotkeyCenter { [weak panel] in
            panel?.toggle()
        }
        panel.show()
        TecloraLog.info("Teclora pronto")
    }
}
