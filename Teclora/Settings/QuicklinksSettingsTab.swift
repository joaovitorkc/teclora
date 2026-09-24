import SwiftUI

struct QuicklinksSettingsTab: View {
    @Bindable var store: QuicklinkStore
    @State private var name = ""
    @State private var target = ""
    @State private var editing: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Nome", text: $name)
            TextField("URL ou caminho", text: $target)
            HStack {
                Button(editing == nil ? "Adicionar" : "Salvar", action: save)
                    .disabled(trimmedEmpty)
                if editing != nil {
                    Button("Cancelar", action: clear)
                }
            }
            Text("Enter no launcher abre o link ou o arquivo.")
                .font(.callout)
                .foregroundStyle(.secondary)
            List(store.links) { link in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(link.name).lineLimit(1)
                        Text(link.target)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Button("Editar") { beginEdit(link) }
                    Button("Apagar", role: .destructive) { store.delete(link.id) }
                }
            }
        }
        .padding(16)
    }

    private var trimmedEmpty: Bool {
        name.trimmingCharacters(in: .whitespaces).isEmpty
            || target.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        if let editing, let current = store.links.first(where: { $0.id == editing }) {
            store.update(Quicklink(id: current.id, name: name, target: target))
        } else {
            store.add(name: name, target: target)
        }
        clear()
    }

    private func beginEdit(_ link: Quicklink) {
        editing = link.id
        name = link.name
        target = link.target
    }

    private func clear() {
        editing = nil
        name = ""
        target = ""
    }
}
