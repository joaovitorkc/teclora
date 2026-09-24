import KeyboardShortcuts
import SwiftUI

enum SettingsTab: Hashable {
    case general
    case clipboard
    case snippets
    case quicklinks
    case tecpet
    case cursor
}

struct SettingsView: View {
    @Bindable var model: SettingsModel

    var body: some View {
        TabView(selection: $model.selectedTab) {
            GeneralSettingsTab()
                .tabItem { Label("Geral", systemImage: "gearshape") }
                .tag(SettingsTab.general)
            ClipboardSettingsTab(model: model)
                .tabItem { Label("Clipboard", systemImage: "doc.on.clipboard") }
                .tag(SettingsTab.clipboard)
            SnippetsSettingsTab(store: model.snippets)
                .tabItem { Label("Snippets", systemImage: "text.quote") }
                .tag(SettingsTab.snippets)
            QuicklinksSettingsTab(store: model.quicklinks)
                .tabItem { Label("Quicklinks", systemImage: "link") }
                .tag(SettingsTab.quicklinks)
            TecpetSettingsTab(store: model.tecpet)
                .tabItem { Label("Tecpet", systemImage: "pawprint") }
                .tag(SettingsTab.tecpet)
            CursorSettingsTab(model: model.cursor)
                .tabItem { Label("Cursor", systemImage: "key") }
                .tag(SettingsTab.cursor)
        }
        .tabViewStyle(.automatic)
        .frame(width: 520, height: 440)
    }
}

/// Ponte observável: a janela SwiftUI lê o store e o histórico.
@MainActor
@Observable
final class SettingsModel {
    private let settings: SettingsStore
    private let clipboard: ClipboardStore
    let snippets: SnippetStore
    let quicklinks: QuicklinkStore
    let tecpet: TecpetStore
    let cursor: CursorSettingsModel
    var recordClipboard: Bool
    var clipboardLimit: Int
    var selectedTab: SettingsTab = .general

    init(
        settings: SettingsStore,
        clipboard: ClipboardStore,
        snippets: SnippetStore,
        quicklinks: QuicklinkStore,
        tecpet: TecpetStore,
        brain: TecpetBrain
    ) {
        self.settings = settings
        self.clipboard = clipboard
        self.snippets = snippets
        self.quicklinks = quicklinks
        self.tecpet = tecpet
        cursor = CursorSettingsModel(brain: brain)
        recordClipboard = settings.recordClipboard
        clipboardLimit = settings.clipboardLimit
    }

    func setRecordClipboard(_ value: Bool) {
        recordClipboard = value
        settings.setRecordClipboard(value)
    }

    func setClipboardLimit(_ value: Int) {
        clipboardLimit = value
        settings.setClipboardLimit(value)
    }

    /// Sobe quando o histórico muda, para a lista redesenhar.
    private(set) var revision = 0

    var entries: [ClipboardEntry] { clipboard.entries }

    func noteChange() { revision += 1 }

    func copy(_ id: UUID) { clipboard.copyBack(id) }
    func togglePin(_ id: UUID) { clipboard.togglePin(id) }
    func delete(_ id: UUID) { clipboard.delete(id) }
}

private struct GeneralSettingsTab: View {
    var body: some View {
        Form {
            LabeledContent("Atalho do painel") {
                KeyboardShortcuts.Recorder("Mostrar o Teclora", name: .toggleLauncher)
            }
            Text("Option+Space abre e fecha o Teclora. O app fica fora do Dock, na barra de menu.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(12)
    }
}

private struct ClipboardSettingsTab: View {
    @Bindable var model: SettingsModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Gravar histórico", isOn: Binding(
                get: { model.recordClipboard },
                set: { model.setRecordClipboard($0) }
            ))
            Picker("Tamanho máximo", selection: Binding(
                get: { model.clipboardLimit },
                set: { model.setClipboardLimit($0) }
            )) {
                ForEach(TecloraSettings.limitChoices, id: \.self) { count in
                    Text("\(count) itens").tag(count)
                }
            }
            .pickerStyle(.menu)
            Text("Só texto, neste Mac. Nada disso sai para a rede.")
                .font(.callout)
                .foregroundStyle(.secondary)
            List {
                ForEach(model.entries) { entry in
                    ClipboardSettingsRow(
                        entry: entry,
                        onPin: { model.togglePin(entry.id) },
                        onCopy: { model.copy(entry.id) },
                        onDelete: { model.delete(entry.id) }
                    )
                }
            }
            .id(model.revision)
        }
        .padding(16)
    }
}

private struct ClipboardSettingsRow: View {
    let entry: ClipboardEntry
    let onPin: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preview)
                    .lineLimit(2)
                Text(entry.pinned ? "Fixado" : entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button(entry.pinned ? "Desafixar" : "Fixar", action: onPin)
            Button("Copiar", action: onCopy)
            Button("Apagar", role: .destructive, action: onDelete)
        }
        .padding(.vertical, 4)
    }

    private var preview: String {
        entry.text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}
