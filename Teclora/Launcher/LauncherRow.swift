import AppKit
import SwiftUI

struct LauncherSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 4)
    }
}

struct LauncherRow: View {
    let item: LauncherItem
    let isSelected: Bool
    let isRunning: Bool
    /// 1…9 enquanto ⌘ está segurado.
    let shortcutNumber: Int?

    var body: some View {
        HStack(spacing: 12) {
            icon
                .frame(width: TecloraChrome.iconSize, height: TecloraChrome.iconSize)
            Text(item.title)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Spacer(minLength: 12)
            trailing
        }
        .padding(.horizontal, 10)
        .frame(height: TecloraChrome.rowHeight)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: TecloraChrome.rowCorner, style: .continuous)
                    .fill(TecloraChrome.selectionFill)
                    .overlay {
                        RoundedRectangle(cornerRadius: TecloraChrome.rowCorner, style: .continuous)
                            .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                    }
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var trailing: some View {
        if let shortcutNumber {
            TecloraKeycap(label: "⌘\(shortcutNumber)")
        } else if isRunning {
            Text("Aberto")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        } else if case .quit = item {
            Text("Comando")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder
    private var icon: some View {
        switch item {
        case .application(let app):
            Image(nsImage: AppIconCache.icon(for: app))
                .resizable()
                .interpolation(.high)
        case .quit:
            Image(systemName: "power")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26, height: 26)
                .background(TecloraChrome.platterFill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}
