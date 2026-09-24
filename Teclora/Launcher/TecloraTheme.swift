import SwiftUI

/// Medidas do painel. Cores vêm do sistema (claro/escuro); o vidro é o
/// `NSVisualEffectView` por trás (ver `GlassBackdrop`).
enum TecloraChrome {
    static let panelWidth: CGFloat = 680
    static let corner: CGFloat = 26
    static let searchHeight: CGFloat = 72
    static let searchFieldCorner: CGFloat = 16
    static let rowHeight: CGFloat = 44
    static let rowCorner: CGFloat = 12
    static let iconSize: CGFloat = 30
    static let listHeight: CGFloat = 360
    static let footerHeight: CGFloat = 40
    static let pageSize = 8

    /// Altura fixa: o campo de busca não "pula" enquanto você digita.
    static var panelHeight: CGFloat { searchHeight + listHeight + footerHeight }

    /// Blocos translúcidos por cima do vidro (campo de busca, seleção, teclas).
    static let platterFill = Color.primary.opacity(0.07)
    static let selectionFill = Color.primary.opacity(0.11)

    /// Borda de luz do vidro: mais clara em cima, some embaixo.
    static let rimLight = LinearGradient(
        colors: [.white.opacity(0.42), .white.opacity(0.10), .white.opacity(0.18)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct TecloraKeycap: View {
    let label: String

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 18)
            .background(TecloraChrome.platterFill, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
            }
    }
}
