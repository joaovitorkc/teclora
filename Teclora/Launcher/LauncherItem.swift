import Foundation

/// O que a busca devolve. Apps, clipboard e comandos usam o mesmo formato.
struct LauncherItem: Identifiable, Sendable {
    let id: String
    let title: String
    let subtitle: String?
    /// Título da seção ("Recentes", "Aplicativos", "Clipboard", "Comandos").
    let section: String
    let action: LauncherAction
    let kind: LauncherKind
}

enum LauncherAction: Sendable {
    case openApp(InstalledApp)
    case quit
    case copyClipboard(UUID)
    case openSettings
    case copyText(String)
    case newSnippet
    case lockScreen
    case sleep
    case emptyTrash
    case toggleMute
    case openTarget(String)
}

enum LauncherKind: Sendable {
    case application(InstalledApp)
    case clipboard(id: UUID, pinned: Bool)
    case command(symbol: String)
}

struct LauncherSection: Identifiable {
    let title: String
    let items: [LauncherItem]
    /// Índice global do primeiro item (a seleção é uma lista plana).
    let startIndex: Int

    var id: String { title }
}

extension LauncherItem {
    static func application(_ app: InstalledApp, section: String) -> LauncherItem {
        LauncherItem(
            id: "app.\(app.id)",
            title: app.name,
            subtitle: nil,
            section: section,
            action: .openApp(app),
            kind: .application(app)
        )
    }
}
