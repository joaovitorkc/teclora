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
        showSettings: () -> Void
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
            showSettings()
        }
    }

    static func deleteClipboard(_ id: UUID, clipboard: ClipboardStore) {
        clipboard.delete(id)
    }
}
