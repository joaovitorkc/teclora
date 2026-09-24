import AppKit

/// Vidro fosco estilo iOS 18: desfoca o que está *atrás* da janela
/// (desktop, outros apps), não só o conteúdo do próprio painel.
enum GlassBackdrop {
    @MainActor
    static func wrap(_ content: NSView, cornerRadius: CGFloat) -> NSVisualEffectView {
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.isEmphasized = false
        glass.maskImage = roundedMask(radius: cornerRadius)

        content.translatesAutoresizingMaskIntoConstraints = false
        glass.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            content.topAnchor.constraint(equalTo: glass.topAnchor),
            content.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])
        return glass
    }

    /// Máscara 9-slice: cantos fixos, meio esticável. A sombra da janela segue o recorte.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }
}
