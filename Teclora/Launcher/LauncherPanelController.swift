import AppKit
import SwiftUI

final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class LauncherPanelController: NSObject, NSWindowDelegate {
    private let model: LauncherModel
    private let panel: LauncherPanel
    private var previousApp: NSRunningApplication?
    private var localMonitors: [Any] = []
    private var clickMonitor: Any?
    private var ignoringResign = false
    private var isHiding = false

    init(model: LauncherModel) {
        self.model = model
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: TecloraChrome.panelWidth, height: TecloraChrome.panelHeight),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()

        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.title = "Teclora"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        let hosting = NSHostingView(rootView: LauncherView(model: model).ignoresSafeArea())
        hosting.sizingOptions = []
        panel.contentView = GlassBackdrop.wrap(hosting, cornerRadius: TecloraChrome.corner)

        model.onConfirm = { [weak self] item, alternate in
            self?.perform(item, alternate: alternate)
        }
        model.onCancel = { [weak self] in
            self?.hide(restorePrevious: true)
        }
        model.refreshCatalog()
        installLocalMonitors()
    }

    func toggle() {
        if panel.isVisible {
            hide(restorePrevious: true)
        } else {
            show()
        }
    }

    func show() {
        ignoringResign = true
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = front
        }
        model.refreshCatalog()
        model.resetForDisplay()
        positionPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        panel.makeKey()
        startClickOutsideMonitor()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.panel.makeKeyAndOrderFront(nil)
            self.ignoringResign = false
        }
    }

    func hide(restorePrevious: Bool) {
        guard !isHiding else { return }
        isHiding = true
        stopClickOutsideMonitor()
        if panel.isVisible {
            panel.orderOut(nil)
        }
        if restorePrevious {
            activatePrevious()
        } else {
            previousApp = nil
        }
        isHiding = false
    }

    func windowDidResignKey(_ notification: Notification) {
        guard !ignoringResign, panel.isVisible else { return }
        if StatusItemController.isCurrentEventOnButton() { return }
        hide(restorePrevious: false)
    }

    private func startClickOutsideMonitor() {
        stopClickOutsideMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                if StatusItemController.isCurrentEventOnButton() { return }
                self.hide(restorePrevious: false)
            }
        }
    }

    private func stopClickOutsideMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }

    private func installLocalMonitors() {
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let code = event.keyCode
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let swallow = MainActor.assumeIsolated {
                self.handleKey(code: code, flags: flags)
            }
            return swallow ? nil : event
        }
        let modifiers = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            let command = event.modifierFlags.contains(.command)
            MainActor.assumeIsolated {
                guard let self, self.model.commandHeld != command else { return }
                self.model.commandHeld = command
            }
            return event
        }
        let pointer = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, !self.model.pointerSelectionEnabled else { return }
                self.model.pointerSelectionEnabled = true
            }
            return event
        }
        localMonitors = [keys, modifiers, pointer].compactMap { $0 }
    }

    private func handleKey(code: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        guard panel.isVisible else { return false }
        if code == KeyCode.escape {
            model.cancel()
            return true
        }
        guard panel.isKeyWindow else { return false }

        if flags == .command, let number = KeyCode.digits.firstIndex(of: code) {
            model.confirm(at: number)
            return true
        }
        if flags == .control, let delta = KeyCode.emacsMoves[code] {
            model.moveSelection(delta)
            return true
        }

        switch code {
        case KeyCode.returnKey, KeyCode.enter:
            model.confirmSelection(alternate: flags.contains(.command))
        case KeyCode.delete, KeyCode.forwardDelete:
            guard flags.contains(.command), case .clipboard = model.selectedItem?.kind else {
                return false
            }
            deleteSelectedClipboard()
        case KeyCode.down:
            model.moveSelection(1)
        case KeyCode.up:
            model.moveSelection(-1)
        case KeyCode.tab:
            model.moveSelection(flags.contains(.shift) ? -1 : 1)
        case KeyCode.pageDown:
            model.moveSelection(TecloraChrome.pageSize, wrap: false)
        case KeyCode.pageUp:
            model.moveSelection(-TecloraChrome.pageSize, wrap: false)
        default:
            return false
        }
        return true
    }

    var onPerform: ((LauncherItem, Bool) -> Void)?
    var onDeleteClipboard: ((UUID) -> Void)?

    private func perform(_ item: LauncherItem, alternate: Bool) {
        onPerform?(item, alternate)
    }

    private func deleteSelectedClipboard() {
        guard case .clipboard(let id, _) = model.selectedItem?.kind else { return }
        onDeleteClipboard?(id)
    }

    private func activatePrevious() {
        let previous = previousApp
        previousApp = nil
        previous?.activate()
    }

    private func positionPanel() {
        let size = NSSize(width: TecloraChrome.panelWidth, height: TecloraChrome.panelHeight)
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else {
            panel.setFrame(NSRect(x: 200, y: 200, width: size.width, height: size.height), display: true)
            return
        }
        let visible = screen.visibleFrame
        var x = visible.midX - size.width / 2
        var y = visible.maxY - size.height - (visible.height * 0.16)
        x = min(max(x, visible.minX + 12), visible.maxX - size.width - 12)
        y = min(max(y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }
}

/// Códigos de tecla (layout-independentes) usados pelo painel.
private enum KeyCode {
    static let returnKey: UInt16 = 36
    static let enter: UInt16 = 76
    static let tab: UInt16 = 48
    static let escape: UInt16 = 53
    static let down: UInt16 = 125
    static let up: UInt16 = 126
    static let pageUp: UInt16 = 116
    static let pageDown: UInt16 = 121
    static let delete: UInt16 = 51
    static let forwardDelete: UInt16 = 117
    /// 1…9 na fileira de números.
    static let digits: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
    /// ⌃N / ⌃P e ⌃J / ⌃K, como em editores e no Raycast.
    static let emacsMoves: [UInt16: Int] = [45: 1, 35: -1, 38: 1, 40: -1]
}
