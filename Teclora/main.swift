import AppKit

/// Sem MainMenu.xib o `@main` no AppDelegate só chama `NSApplicationMain`
/// e o delegate nunca é criado — o processo fica no ar sem janela.
let tecloraApp = NSApplication.shared
let tecloraDelegate = MainActor.assumeIsolated { AppDelegate() }
tecloraApp.setActivationPolicy(.accessory)
tecloraApp.delegate = tecloraDelegate
DispatchQueue.main.async {
    MainActor.assumeIsolated {
        tecloraDelegate.startLauncher()
    }
}
withExtendedLifetime(tecloraDelegate) {
    tecloraApp.run()
}
