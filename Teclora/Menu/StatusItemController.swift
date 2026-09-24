import AppKit

/// Ícone template na barra de menu. Clique esquerdo alterna o painel; o direito abre o menu.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let onToggle: () -> Void
    private let onOpen: () -> Void
    private let onSettings: () -> Void
    private let onQuit: () -> Void
    private var menu: NSMenu?

    /// O painel não trata clique neste botão como "clique fora".
    static weak var button: NSStatusBarButton?

    init(
        onToggle: @escaping () -> Void,
        onOpen: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onToggle = onToggle
        self.onOpen = onOpen
        self.onSettings = onSettings
        self.onQuit = onQuit
        super.init()
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "command", accessibilityDescription: "Teclora")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "Teclora"
        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        Self.button = button
        menu = makeMenu()
    }

    static func isCurrentEventOnButton() -> Bool {
        guard let event = NSApp.currentEvent, let button, let window = button.window else { return false }
        let screenPoint: NSPoint
        if event.window == nil {
            screenPoint = event.locationInWindow
        } else {
            screenPoint = event.window?.convertPoint(toScreen: event.locationInWindow) ?? event.locationInWindow
        }
        return window.frame.contains(screenPoint)
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let type = NSApp.currentEvent?.type else { return }
        if type == .rightMouseUp {
            showMenu()
            return
        }
        onToggle()
    }

    private func showMenu() {
        guard let menu, let button = statusItem.button else { return }
        let location = NSPoint(x: 0, y: button.bounds.height + 4)
        menu.popUp(positioning: nil, at: location, in: button)
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Teclora", action: #selector(openLauncher)))
        menu.addItem(item("Preferências", action: #selector(openSettings), key: ","))
        menu.addItem(.separator())
        menu.addItem(item("Sair", action: #selector(quit), key: "q"))
        return menu
    }

    private func item(_ title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func openLauncher() { onOpen() }
    @objc private func openSettings() { onSettings() }
    @objc private func quit() { onQuit() }
}
