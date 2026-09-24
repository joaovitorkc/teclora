import Foundation

/// Allowlist fixa. Só aparece quando a busca casa o nome. Nada além desta lista.
@MainActor
final class LocalSystemProvider: CommandProvider {
    private struct Command {
        let id: String
        let title: String
        let subtitle: String
        let symbol: String
        let action: LauncherAction
        let aliases: [String]
    }

    func hits(for query: String) -> [LauncherItem] {
        guard !query.isEmpty else { return [] }
        let now = Date()
        let stamp = now.formatted(date: .numeric, time: .standard)
        let uuid = UUID().uuidString
        return commands(stamp: stamp, uuid: uuid).compactMap { command in
            let names = [command.title] + command.aliases
            let matched = names.contains { name in
                AppSearch.matchRank(name: AppSearch.fold(name), query: query).map { $0 <= 4 } ?? false
            }
            guard matched else { return nil }
            return LauncherItem(
                id: command.id,
                title: command.title,
                subtitle: command.subtitle,
                section: "Comandos",
                action: command.action,
                kind: .command(symbol: command.symbol)
            )
        }
    }

    private func commands(stamp: String, uuid: String) -> [Command] {
        [
            Command(
                id: "teclora.lock",
                title: "Bloquear tela",
                subtitle: "Sistema",
                symbol: "lock",
                action: .lockScreen,
                aliases: ["lock", "trancar", "bloquear"]
            ),
            Command(
                id: "teclora.sleep",
                title: "Dormir",
                subtitle: "Sistema",
                symbol: "moon",
                action: .sleep,
                aliases: ["sleep", "suspender", "repousar"]
            ),
            Command(
                id: "teclora.trash",
                title: "Esvaziar o Lixo",
                subtitle: "Pede confirmação",
                symbol: "trash",
                action: .emptyTrash,
                aliases: ["lixo", "trash", "esvaziar lixo"]
            ),
            Command(
                id: "teclora.mute",
                title: "Mudo",
                subtitle: "Alterna o volume",
                symbol: "speaker.slash",
                action: .toggleMute,
                aliases: ["unmute", "silenciar", "volume", "mudo"]
            ),
            Command(
                id: "teclora.uuid",
                title: uuid,
                subtitle: "UUID",
                symbol: "number",
                action: .copyText(uuid),
                aliases: ["uuid", "guid", "identificador"]
            ),
            Command(
                id: "teclora.datetime",
                title: stamp,
                subtitle: "Data e hora",
                symbol: "calendar",
                action: .copyText(stamp),
                aliases: ["data", "hora", "data-hora", "agora"]
            ),
        ]
    }
}
