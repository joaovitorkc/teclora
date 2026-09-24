import AppKit

struct InstalledApp: Identifiable, Sendable {
    let id: String
    let name: String
    /// Nome do bundle no disco (ex.: "Calculator" quando o nome exibido é "Calculadora").
    let fileName: String
    let bundleID: String?
    let url: URL
}
