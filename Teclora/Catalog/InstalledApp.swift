import AppKit

struct InstalledApp: Identifiable, Sendable {
    let id: String
    let name: String
    /// Nome do bundle no disco (ex.: "Calculator" quando o nome exibido é "Calculadora").
    let fileName: String
    let bundleID: String?
    let url: URL
}

enum LauncherItem: Identifiable {
    case application(InstalledApp)
    case quit

    var id: String {
        switch self {
        case .application(let app): app.id
        case .quit: "teclora.quit"
        }
    }

    var title: String {
        switch self {
        case .application(let app): app.name
        case .quit: "Sair do Teclora"
        }
    }
}

struct LauncherSection: Identifiable {
    let title: String
    let items: [LauncherItem]
    /// Índice global do primeiro item (seleção é uma lista plana).
    let startIndex: Int

    var id: String { title }
}
