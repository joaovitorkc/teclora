import AppKit

/// Executa a ação do hit: abrir, revelar, sair, copiar clipboard, preferências.
@MainActor
enum ConfirmRouter {
    static func perform(
        item: LauncherItem,
        alternate: Bool,
        history: LaunchHistory,
        clipboard: ClipboardStore,
        closeLauncher: (_ restorePrevious: Bool) -> Void,
        showSettings: (SettingsTab) -> Void
    ) {
        if alternate, case .application(let app) = item.kind {
            closeLauncher(false)
            NSWorkspace.shared.activateFileViewerSelecting([app.url])
            return
        }
        if alternate, case .clipboard(let id, _) = item.kind {
            clipboard.togglePin(id)
            return
        }

        switch item.action {
        case .openApp(let app):
            history.record(app.id)
            closeLauncher(false)
            if !NSWorkspace.shared.open(app.url) {
                TecloraLog.error("Não abriu o aplicativo")
            }
        case .quit:
            closeLauncher(false)
            NSApp.terminate(nil)
        case .copyClipboard(let id):
            clipboard.copyBack(id)
            closeLauncher(false)
        case .openSettings:
            closeLauncher(false)
            showSettings(.general)
        case .copyText(let text):
            copyToPasteboard(text)
            closeLauncher(false)
        case .newSnippet:
            closeLauncher(false)
            showSettings(.snippets)
        case .lockScreen:
            closeLauncher(false)
            SystemActions.lockScreen()
        case .sleep:
            closeLauncher(false)
            SystemActions.sleep()
        case .emptyTrash:
            closeLauncher(false)
            SystemActions.confirmEmptyTrash()
        case .toggleMute:
            closeLauncher(false)
            SystemActions.toggleMute()
        case .openTarget(let target):
            closeLauncher(false)
            SystemActions.openTarget(target)
        case .openFile(let path):
            closeLauncher(false)
            let url = URL(fileURLWithPath: path)
            if alternate {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } else if !NSWorkspace.shared.open(url) {
                TecloraLog.error("Não abriu o arquivo")
            }
        case .focusWindow(let target):
            closeLauncher(false)
            WindowActions.focus(target)
        case .placeWindow(let target, let placement):
            closeLauncher(false)
            WindowActions.place(target, placement)
        case .openAccessibilitySettings:
            closeLauncher(false)
            WindowActions.openAccessibilitySettings()
        }
    }

    private static func copyToPasteboard(_ text: String) {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
    }

    static func deleteClipboard(_ id: UUID, clipboard: ClipboardStore) {
        clipboard.delete(id)
    }
}
