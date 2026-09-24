import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: LauncherPanelController?
    private var hotkeys: HotkeyCenter?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?
    private var clipboardMonitor: ClipboardMonitor?

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
        let history = LaunchHistory()
        let settingsWindow = SettingsWindowController(settings: settings, clipboard: clipboard)
        let model = LauncherModel(
            history: history,
            providers: [ClipboardProvider(store: clipboard), SystemCommandProvider()]
        )
        let panel = LauncherPanelController(model: model)

        panel.onPerform = { [weak panel] item, alternate in
            guard let panel else { return }
            ConfirmRouter.perform(
                item: item,
                alternate: alternate,
                history: history,
                clipboard: clipboard,
                closeLauncher: { panel.hide(restorePrevious: $0) },
                showSettings: { settingsWindow.show() }
            )
        }
        panel.onDeleteClipboard = { id in
            ConfirmRouter.deleteClipboard(id, clipboard: clipboard)
        }
        clipboard.onChange = { [weak model] in
            model?.refreshHits()
            settingsWindow.noteDataChange()
        }
        settings.onChange = { [weak model] in
            clipboard.applyLimit()
            model?.refreshHits()
            settingsWindow.noteDataChange()
        }

        let monitor = ClipboardMonitor(store: clipboard)
        monitor.start()

        panelController = panel
        self.settingsWindow = settingsWindow
        clipboardMonitor = monitor
        statusItem = StatusItemController(
            onToggle: { [weak panel] in panel?.toggle() },
            onOpen: { [weak panel] in panel?.show() },
            onSettings: { settingsWindow.show() },
            onQuit: { NSApp.terminate(nil) }
        )
        hotkeys = HotkeyCenter { [weak panel] in
            panel?.toggle()
        }
        panel.show()
        TecloraLog.info("Teclora pronto")
    }
}
