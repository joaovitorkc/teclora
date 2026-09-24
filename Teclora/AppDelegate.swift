import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: LauncherPanelController?
    private var hotkeys: HotkeyCenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        startLauncher()
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        panelController?.show()
        return false
    }

    func startLauncher() {
        if panelController == nil {
            let controller = LauncherPanelController()
            panelController = controller
            controller.show()
            hotkeys = HotkeyCenter { [weak controller] in
                controller?.toggle()
            }
            return
        }
        panelController?.show()
    }
}
