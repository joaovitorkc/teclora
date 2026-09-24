import AppKit

/// As seis custom tools. Destrutivo pede NSAlert. Sem shell e sem disco genérico.
@MainActor
enum TecpetTools {
    static func definitions() -> [String: [String: Any]] {
        [
            "web_search": tool("Busca curta na web.", ["query": "string"], ["query"]),
            "open_url": tool("Abre uma URL http(s).", ["url": "string"], ["url"]),
            "open_app": tool("Abre um aplicativo pelo nome.", ["name": "string"], ["name"]),
            "open_file": tool("Abre um arquivo dentro da pasta do usuário.", ["path": "string"], ["path"]),
            "clipboard_write": tool("Copia texto para o clipboard local.", ["text": "string"], ["text"]),
            "system_action": tool(
                "Ação da allowlist: mute, lock, sleep, emptyTrash, uuid, datetime.",
                ["action": "string"],
                ["action"]
            ),
        ]
    }

    static func run(_ name: String, _ args: [String: Any], clipboard: ClipboardStore, history: LaunchHistory) -> [String: Any] {
        switch name {
        case "web_search":
            return search(args["query"] as? String ?? "")
        case "open_url":
            return openURL(args["url"] as? String ?? "")
        case "open_app":
            return openApp(args["name"] as? String ?? "", history: history, clipboard: clipboard)
        case "open_file":
            return openFile(args["path"] as? String ?? "")
        case "clipboard_write":
            return writeClipboard(args["text"] as? String ?? "", clipboard: clipboard)
        case "system_action":
            return system(args["action"] as? String ?? "")
        default:
            return ["ok": false, "error": "tool desconhecida"]
        }
    }

    private static func tool(_ description: String, _ props: [String: String], _ required: [String]) -> [String: Any] {
        let properties = props.mapValues { ["type": $0] }
        return [
            "description": description,
            "inputSchema": ["type": "object", "properties": properties, "required": required],
        ]
    }

    private static func search(_ query: String) -> [String: Any] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.duckduckgo.com/?q=\(encoded)&format=json&no_html=1") else {
            return ["ok": false, "found": false]
        }
        let data = (try? Data(contentsOf: url)) ?? Data()
        let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let abstract = (json?["AbstractText"] as? String) ?? ""
        if abstract.isEmpty { return ["ok": true, "found": false, "message": "não achou"] }
        return ["ok": true, "found": true, "text": abstract]
    }

    private static func openURL(_ raw: String) -> [String: Any] {
        guard let url = URL(string: raw), let scheme = url.scheme, scheme == "http" || scheme == "https" else {
            return ["ok": false, "error": "url recusada"]
        }
        let opened = NSWorkspace.shared.open(url)
        return ["ok": opened]
    }

    private static func openApp(_ name: String, history: LaunchHistory, clipboard: ClipboardStore) -> [String: Any] {
        let folded = AppSearch.fold(name)
        let apps = AppCatalog.load(excluding: Bundle.main.bundleIdentifier)
        let match = apps.compactMap { app -> (Int, InstalledApp)? in
            let keys = [app.name, app.fileName].map(AppSearch.fold)
            guard let rank = keys.compactMap({ AppSearch.matchRank(name: $0, query: folded) }).min() else { return nil }
            return (rank, app)
        }.min { $0.0 < $1.0 }?.1
        guard let match else { return ["ok": false, "error": "app não achado"] }
        ConfirmRouter.perform(
            item: LauncherItem.application(match, section: "Aplicativos"),
            alternate: false,
            history: history,
            clipboard: clipboard,
            closeLauncher: { _ in },
            showSettings: { _ in }
        )
        return ["ok": true, "app": match.name]
    }

    private static func openFile(_ raw: String) -> [String: Any] {
        if raw.contains("..") { return ["ok": false, "error": "caminho recusado"] }
        let expanded = (raw as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded).standardizedFileURL
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard url.path.hasPrefix(home) else { return ["ok": false, "error": "fora da pasta do usuário"] }
        let opened = NSWorkspace.shared.open(url)
        return ["ok": opened]
    }

    private static func writeClipboard(_ text: String, clipboard: ClipboardStore) -> [String: Any] {
        let board = NSPasteboard.general
        board.clearContents()
        board.setString(text, forType: .string)
        clipboard.syncChangeCount(board.changeCount)
        return ["ok": true]
    }

    private static func system(_ action: String) -> [String: Any] {
        switch action {
        case "mute":
            SystemActions.toggleMute()
        case "lock":
            guard confirm("Bloquear a tela?") else { return ["ok": false, "cancelled": true] }
            SystemActions.lockScreen()
        case "sleep":
            guard confirm("Colocar o Mac para dormir?") else { return ["ok": false, "cancelled": true] }
            SystemActions.sleep()
        case "emptyTrash":
            guard SystemActions.confirmEmptyTrash() else { return ["ok": false, "cancelled": true] }
        case "uuid":
            return ["ok": true, "value": UUID().uuidString]
        case "datetime":
            return ["ok": true, "value": Date().formatted(date: .numeric, time: .standard)]
        default:
            return ["ok": false, "error": "ação fora da allowlist"]
        }
        return ["ok": true, "action": action]
    }

    private static func confirm(_ message: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "Pode")
        alert.addButton(withTitle: "Cancelar")
        return alert.runModal() == .alertFirstButtonReturn
    }
}
