import AppKit

/// Efeitos da allowlist. O router só chama estes métodos.
@MainActor
enum SystemActions {
    static func lockScreen() {
        let session = "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession"
        if FileManager.default.isExecutableFile(atPath: session) {
            run(session, ["-suspend"])
            return
        }
        runAppleScript(
            "tell application \"System Events\" to keystroke \"q\" using {control down, command down}"
        )
    }

    static func sleep() {
        run("/usr/bin/pmset", ["sleepnow"])
    }

    static func confirmEmptyTrash() {
        let alert = NSAlert()
        alert.messageText = "Esvaziar o Lixo?"
        alert.informativeText = "Os itens do Lixo serão apagados."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Esvaziar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        runAppleScript("tell application \"Finder\" to empty trash")
    }

    static func toggleMute() {
        runAppleScript(
            """
            set isMuted to output muted of (get volume settings)
            if isMuted then
                set volume without output muted
            else
                set volume with output muted
            end if
            """
        )
    }

    static func openTarget(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") || trimmed.hasPrefix("file:") {
            openFile(trimmed)
            return
        }
        if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
            if !NSWorkspace.shared.open(url) {
                TecloraLog.error("Não abriu o quicklink")
            }
            return
        }
        openFile(trimmed)
    }

    private static func openFile(_ raw: String) {
        let path = (raw as NSString).expandingTildeInPath
        let url = raw.hasPrefix("file:") ? URL(string: raw) : URL(fileURLWithPath: path)
        guard let url else {
            TecloraLog.error("Quicklink sem destino")
            return
        }
        if !NSWorkspace.shared.open(url) {
            TecloraLog.error("Não abriu o quicklink")
        }
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            TecloraLog.error("Não executou a ação de sistema")
        }
    }

    private static func runAppleScript(_ source: String) {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if error != nil || result == nil {
            TecloraLog.error("Ação de sistema falhou")
        }
    }
}
