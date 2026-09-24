import Foundation

/// Fonte de hits que não são aplicativos instalados.
@MainActor
protocol CommandProvider: AnyObject {
    func hits(for query: String) -> [LauncherItem]
}

/// Preferências e sair. A busca casa título e aliases ("settings", "sair").
@MainActor
final class SystemCommandProvider: CommandProvider {
    private struct Command {
        let id: String
        let title: String
        let symbol: String
        let action: LauncherAction
        let aliases: [String]
    }

    private let commands: [Command] = [
        Command(
            id: "teclora.settings",
            title: "Preferências",
            symbol: "gearshape",
            action: .openSettings,
            aliases: ["preferencias", "settings", "ajustes", "preferências"]
        ),
        Command(
            id: "teclora.quit",
            title: "Sair do Teclora",
            symbol: "power",
            action: .quit,
            aliases: ["sair do teclora", "quit teclora", "fechar teclora", "sair"]
        ),
    ]

    func hits(for query: String) -> [LauncherItem] {
        let folded = AppSearch.fold(query)
        return commands.compactMap { command in
            guard folded.isEmpty || matches(command, query: folded) else { return nil }
            return LauncherItem(
                id: command.id,
                title: command.title,
                subtitle: "Comando",
                section: "Comandos",
                action: command.action,
                kind: .command(symbol: command.symbol)
            )
        }
    }

    private func matches(_ command: Command, query: String) -> Bool {
        let names = [AppSearch.fold(command.title)] + command.aliases.map(AppSearch.fold)
        return names.contains { name in
            AppSearch.matchRank(name: name, query: query).map { $0 <= 4 } ?? false
        }
    }
}
