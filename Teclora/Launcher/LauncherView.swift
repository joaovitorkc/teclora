import AppKit
import SwiftUI

struct LauncherView: View {
    @Bindable var model: LauncherModel
    @FocusState private var searchFocused: Bool

    private let shape = RoundedRectangle(cornerRadius: TecloraChrome.corner, style: .circular)

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            results
                .frame(height: TecloraChrome.listHeight)
            footer
        }
        .frame(width: TecloraChrome.panelWidth, height: TecloraChrome.panelHeight)
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(TecloraChrome.rimLight, lineWidth: 1)
        }
        .onChange(of: model.focusToken) {
            searchFocused = true
        }
        .onAppear {
            searchFocused = true
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Buscar", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 20))
                .focused($searchFocused)

            if !model.query.isEmpty {
                Button {
                    model.query = ""
                    searchFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Limpar busca (esc)")
            }
        }
        .padding(.horizontal, 16)
        .frame(maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: TecloraChrome.searchFieldCorner, style: .continuous)
                .fill(TecloraChrome.platterFill)
                .overlay {
                    RoundedRectangle(cornerRadius: TecloraChrome.searchFieldCorner, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 0.5)
                }
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 6)
        .frame(height: TecloraChrome.searchHeight)
    }

    @ViewBuilder
    private var results: some View {
        if model.items.isEmpty {
            emptyState
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        Color.clear.frame(height: 0).id(Self.topAnchor)
                        ForEach(model.sections) { section in
                            LauncherSectionHeader(title: section.title)
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { offset, item in
                                row(item, index: section.startIndex + offset)
                            }
                        }
                    }
                    .padding(.horizontal, 10)
                }
                // Margem = faixa do esmaecimento: a linha selecionada para acima dela.
                .safeAreaPadding(.bottom, 28)
                .scrollIndicators(.automatic)
                .mask(Self.bottomFade)
                .onChange(of: model.selectedIndex) {
                    scroll(proxy)
                }
                .onChange(of: model.query) {
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
            }
        }
    }

    private static let topAnchor = "teclora.top"

    /// A lista some suavemente antes do rodapé, em vez de cortar seco.
    private static let bottomFade = LinearGradient(
        stops: [
            .init(color: .black, location: 0),
            .init(color: .black, location: 0.92),
            .init(color: .clear, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    private func row(_ item: LauncherItem, index: Int) -> some View {
        LauncherRow(
            item: item,
            isSelected: index == model.selectedIndex,
            isRunning: isRunning(item),
            shortcutNumber: model.commandHeld && index < 9 ? index + 1 : nil
        )
        .id(item.id)
        .onContinuousHover { phase in
            if case .active = phase, model.pointerSelectionEnabled, model.selectedIndex != index {
                model.selectedIndex = index
            }
        }
        .onTapGesture {
            model.confirm(at: index)
        }
    }

    private func scroll(_ proxy: ScrollViewProxy) {
        guard let item = model.selectedItem else { return }
        if model.selectedIndex == 0 {
            proxy.scrollTo(Self.topAnchor, anchor: .top)
        } else {
            proxy.scrollTo(item.id)
        }
    }

    private func isRunning(_ item: LauncherItem) -> Bool {
        guard case .application(let app) = item.kind else { return false }
        return model.runningPaths.contains(app.id)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("Nenhum resultado para “\(model.query)”")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Dá para buscar pelas iniciais, como “vsc” para Visual Studio Code.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            Text(model.appCount == 1 ? "1 aplicativo" : "\(model.appCount) aplicativos")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            Spacer()
            footerActions
        }
        .padding(.horizontal, 16)
        .frame(height: TecloraChrome.footerHeight)
    }

    @ViewBuilder
    private var footerActions: some View {
        switch model.selectedItem?.action {
        case .openApp:
            hint("Abrir", keys: ["↵"], emphasized: !model.commandHeld)
            hint("Mostrar no Finder", keys: ["⌘", "↵"], emphasized: model.commandHeld)
        case .copyClipboard:
            hint("Copiar", keys: ["↵"], emphasized: !model.commandHeld)
            hint("Fixar", keys: ["⌘", "↵"], emphasized: model.commandHeld)
            hint("Apagar", keys: ["⌘", "⌫"], emphasized: false)
        case .copyText:
            hint("Copiar", keys: ["↵"], emphasized: true)
        case .quit:
            hint("Sair", keys: ["↵"], emphasized: true)
        case .openSettings, .newSnippet:
            hint("Abrir", keys: ["↵"], emphasized: true)
        case .lockScreen, .sleep, .toggleMute:
            hint("Executar", keys: ["↵"], emphasized: true)
        case .emptyTrash:
            hint("Confirmar", keys: ["↵"], emphasized: true)
        case .openTarget, .openAccessibilitySettings:
            hint("Abrir", keys: ["↵"], emphasized: true)
        case .openFile:
            hint("Abrir", keys: ["↵"], emphasized: !model.commandHeld)
            hint("Mostrar no Finder", keys: ["⌘", "↵"], emphasized: model.commandHeld)
        case .focusWindow:
            hint("Focar", keys: ["↵"], emphasized: true)
        case .placeWindow:
            hint("Mover", keys: ["↵"], emphasized: true)
        case nil:
            hint("Limpar busca", keys: ["esc"], emphasized: true)
        }
    }

    private func hint(_ label: String, keys: [String], emphasized: Bool) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: emphasized ? .medium : .regular))
                .foregroundStyle(emphasized ? .secondary : .tertiary)
            HStack(spacing: 2) {
                ForEach(keys, id: \.self) { TecloraKeycap(label: $0) }
            }
        }
    }
}
