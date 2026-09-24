import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleLauncher = Self(
        "toggleLauncher",
        initial: .init(.space, modifiers: [.option])
    )
}

/// Option+Space via Carbon (KeyboardShortcuts). Sem permissão de Acessibilidade.
@MainActor
final class HotkeyCenter {
    init(onToggle: @escaping () -> Void) {
        KeyboardShortcuts.onKeyDown(for: .toggleLauncher, action: onToggle)
    }
}
