import AppKit
import SwiftUI

/// Mascote flutuante. Arrastar gruda no canto mais próximo. Não é o painel de busca.
@MainActor
final class TecpetOverlayController: NSObject {
    private let store: TecpetStore
    private let panel: NSPanel
    private let onOpenChat: () -> Void
    private let onSettings: () -> Void
    private var menu: NSMenu?
    private var monitors: [Any] = []
    private var dragStart: NSPoint?

    init(store: TecpetStore, onOpenChat: @escaping () -> Void, onSettings: @escaping () -> Void) {
        self.store = store
        self.onOpenChat = onOpenChat
        self.onSettings = onSettings
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 72, height: 72),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.ignoresMouseEvents = false
        super.init()
        let host = NSHostingView(rootView: PetPortrait(store: store))
        host.sizingOptions = []
        panel.contentView = host
        installMonitors()
        refresh()
    }

    func refresh() {
        if store.hidden {
            panel.orderOut(nil)
            return
        }
        place(store.corner)
        panel.orderFrontRegardless()
    }

    private func installMonitors() {
        let down = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.window === self.panel else { return }
                self.dragStart = NSEvent.mouseLocation
            }
            return event
        }
        let up = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, event.window === self.panel else { return }
                self.finishDrag()
            }
            return event
        }
        let right = NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { [weak self] event in
            let swallow = MainActor.assumeIsolated { () -> Bool in
                guard let self, event.window === self.panel else { return false }
                self.showMenu(event)
                return true
            }
            return swallow ? nil : event
        }
        monitors = [down, up, right].compactMap { $0 }
    }

    private func finishDrag() {
        let start = dragStart
        dragStart = nil
        let moved = start.map { hypot(NSEvent.mouseLocation.x - $0.x, NSEvent.mouseLocation.y - $0.y) } ?? 0
        let corner = nearestCorner()
        store.setCorner(corner)
        place(corner)
        if moved < 4 { onOpenChat() }
    }

    private func nearestCorner() -> PetCorner {
        guard let screen = panel.screen ?? NSScreen.main else { return store.corner }
        let visible = screen.visibleFrame
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        let candidates: [(PetCorner, CGFloat, CGFloat)] = [
            (.topLeading, visible.minX, visible.maxY),
            (.topTrailing, visible.maxX, visible.maxY),
            (.bottomLeading, visible.minX, visible.minY),
            (.bottomTrailing, visible.maxX, visible.minY),
        ]
        return candidates.min { lhs, rhs in
            hypot(center.x - lhs.1, center.y - lhs.2) < hypot(center.x - rhs.1, center.y - rhs.2)
        }?.0 ?? .bottomTrailing
    }

    private func place(_ corner: PetCorner) {
        guard let screen = panel.screen ?? NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        let pad: CGFloat = 12
        let origin: NSPoint
        switch corner {
        case .topLeading:
            origin = NSPoint(x: visible.minX + pad, y: visible.maxY - size.height - pad)
        case .topTrailing:
            origin = NSPoint(x: visible.maxX - size.width - pad, y: visible.maxY - size.height - pad)
        case .bottomLeading:
            origin = NSPoint(x: visible.minX + pad, y: visible.minY + pad)
        case .bottomTrailing:
            origin = NSPoint(x: visible.maxX - size.width - pad, y: visible.minY + pad)
        }
        panel.setFrameOrigin(origin)
    }

    private func showMenu(_ event: NSEvent) {
        let menu = NSMenu()
        let sound = NSMenuItem(title: store.muted ? "Com som" : "Silenciar", action: #selector(toggleMute), keyEquivalent: "")
        let hide = NSMenuItem(title: "Esconder", action: #selector(hidePet), keyEquivalent: "")
        let settings = NSMenuItem(title: "Ajustes do Tecpet", action: #selector(openSettings), keyEquivalent: "")
        for item in [sound, hide, settings] {
            item.target = self
            menu.addItem(item)
        }
        self.menu = menu
        NSMenu.popUpContextMenu(menu, with: event, for: panel.contentView ?? NSView())
    }

    @objc private func toggleMute() { store.setMuted(!store.muted) }
    @objc private func hidePet() { store.setHidden(true) }
    @objc private func openSettings() { onSettings() }
}

private struct PetPortrait: View {
    let store: TecpetStore
    @State private var lifted = false

    var body: some View {
        Group {
            if let image = store.species.flatMap(SpeciesCatalog.portrait) {
                Image(nsImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 56, height: 56)
            }
        }
        .offset(y: store.muted ? 0 : (lifted ? -3 : 0))
        .animation(store.muted ? nil : .easeInOut(duration: 0.7).repeatForever(autoreverses: true), value: lifted)
        .onAppear { lifted = true }
        .frame(width: 72, height: 72)
    }
}
