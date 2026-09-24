import SwiftUI

struct SnippetsSettingsTab: View {
    @Bindable var store: SnippetStore
    @State private var name = ""
    @State private var shortcut = ""
    @State private var bodyText = ""
    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nome", text: $name)
            TextField("Atalho curto (opcional)", text: $shortcut)
            TextEditor(text: $bodyText)
                .font(.body)
                .frame(minHeight: 80)
                .overlay {
                    RoundedRectangle(cornerRadius: 6).strokeBorder(.separator)
                }
            HStack {
                Button(editing == nil ? "Adicionar" : "Salvar", action: save)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || bodyText.isEmpty)
                if editing != nil {
                    Button("Cancelar", action: clear)
                }
            }
            List(store.snippets) { snippet in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snippet.name).lineLimit(1)
                        Text(snippet.shortcut.isEmpty ? snippet.body : snippet.shortcut)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Editar") { beginEdit(snippet) }
                    Button("Apagar", role: .destructive) { store.delete(snippet.id) }
                }
            }
        }
        .padding(16)
    }

    private func save() {
        if let editing {
            store.update(Snippet(
                id: editing,
                name: name,
                shortcut: shortcut,
                body: bodyText,
                createdAt: store.snippets.first { $0.id == editing }?.createdAt ?? Date()
            ))
        } else {
            store.add(name: name, shortcut: shortcut, body: bodyText)
        }
        clear()
    }

    private func beginEdit(_ snippet: Snippet) {
        editing = snippet.id
        name = snippet.name
        shortcut = snippet.shortcut
        bodyText = snippet.body
    }

    private func clear() {
        editing = nil
        name = ""
        shortcut = ""
        bodyText = ""
    }
}
