import SwiftUI

struct TecpetSettingsTab: View {
    @Bindable var store: TecpetStore
    @State private var memory = TecpetMemory()
    @State private var profile = "{}"
    @State private var profileNote = ""

    var body: some View {
        Form {
            Picker("Espécie", selection: Binding(
                get: { store.speciesId },
                set: { store.selectSpecies($0) }
            )) {
                ForEach(SpeciesCatalog.all) { species in
                    Text(species.defaultName).tag(species.id)
                }
            }
            if let species = store.species {
                Text(species.vibeLabel)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            TextField("Nome para chamar", text: Binding(
                get: { store.wakeName },
                set: { store.setWakeName($0) }
            ))
            Toggle("Responder ao chamar", isOn: Binding(
                get: { store.respondToWake },
                set: { store.setRespondToWake($0) }
            ))
            Toggle("Silenciar", isOn: Binding(
                get: { store.muted },
                set: { store.setMuted($0) }
            ))
            Picker("Barra de menu", selection: Binding(
                get: { store.menuStyle },
                set: { store.setMenuStyle($0) }
            )) {
                ForEach(PetMenuStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            Picker("Canto", selection: Binding(
                get: { store.corner },
                set: { store.setCorner($0) }
            )) {
                ForEach(PetCorner.allCases) { corner in
                    Text(corner.label).tag(corner)
                }
            }
            Toggle("Esconder mascote", isOn: Binding(
                get: { store.hidden },
                set: { store.setHidden($0) }
            ))
            Text("O que o pet sabe")
                .font(.headline)
            TextEditor(text: $profile)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 88)
            HStack {
                Button("Gravar perfil") { profileNote = writeProfile() }
                Text(profileNote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("JSON até 2 KB. Sem key, o chat só abre app (“abrir Safari”). Com key, o Cursor lê este perfil.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .formStyle(.grouped)
        .padding(12)
        .onAppear { profile = memory.profileText() }
    }

    private func writeProfile() -> String {
        switch memory.saveProfile(profile) {
        case .saved:
            return "Gravado."
        case .invalidJSON:
            return "JSON inválido. O arquivo anterior ficou."
        case .tooLarge:
            return "Passou de 2 KB. O arquivo anterior ficou."
        }
    }
}
