import AppKit
import Observation

@MainActor
@Observable
final class LauncherModel {
    var query = "" {
        didSet {
            guard oldValue != query else { return }
            recompute(resetSelection: true)
        }
    }

    var selectedIndex = 0
    private(set) var sections: [LauncherSection] = []
    private(set) var items: [LauncherItem] = []
    private(set) var runningPaths: Set<String> = []
    private(set) var appCount = 0
    /// ⌘ segurado: mostra atalhos ⌘1…⌘9 e a ação secundária no rodapé.
    var commandHeld = false
    /// Só o mouse *se mexendo* muda a seleção — rolar com o teclado sob o
    /// ponteiro parado não rouba a linha selecionada.
    var pointerSelectionEnabled = false
    var focusToken = 0

    @ObservationIgnored var onConfirm: ((LauncherItem, Bool) -> Void)?
    @ObservationIgnored var onCancel: (() -> Void)?
    @ObservationIgnored var onRecomputed: (() -> Void)?
    @ObservationIgnored let history: LaunchHistory
    @ObservationIgnored private let providers: [CommandProvider]
    @ObservationIgnored private var apps: [InstalledApp] = []
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    init(history: LaunchHistory, providers: [CommandProvider]) {
        self.history = history
        self.providers = providers
    }

    var selectedItem: LauncherItem? {
        items.indices.contains(selectedIndex) ? items[selectedIndex] : nil
    }

    /// Mostra o catálogo em cache na hora e atualiza em segundo plano.
    func refreshCatalog() {
        let selfID = Bundle.main.bundleIdentifier
        if apps.isEmpty {
            apply(AppCatalog.load(excluding: selfID))
        }
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            let fresh = await Task.detached(priority: .userInitiated) {
                AppCatalog.load(excluding: selfID)
            }.value
            guard !Task.isCancelled else { return }
            self?.apply(fresh)
        }
    }

    func resetForDisplay() {
        runningPaths = Set(
            NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path }
        )
        commandHeld = false
        pointerSelectionEnabled = false
        if query.isEmpty {
            recompute(resetSelection: true)
        } else {
            query = ""
        }
        focusToken += 1
    }

    func moveSelection(_ delta: Int, wrap: Bool = true) {
        guard !items.isEmpty else { return }
        pointerSelectionEnabled = false
        if wrap {
            selectedIndex = (selectedIndex + delta + items.count) % items.count
        } else {
            selectedIndex = min(max(selectedIndex + delta, 0), items.count - 1)
        }
    }

    func confirmSelection(alternate: Bool = false) {
        guard let item = selectedItem else { return }
        onConfirm?(item, alternate)
    }

    func confirm(at index: Int) {
        guard items.indices.contains(index) else { return }
        selectedIndex = index
        confirmSelection()
    }

    /// Esc limpa a busca primeiro; com a busca vazia, fecha.
    func cancel() {
        if query.isEmpty {
            onCancel?()
        } else {
            query = ""
        }
    }

    func refreshHits() {
        recompute(resetSelection: false)
    }

    private func apply(_ fresh: [InstalledApp]) {
        guard fresh.map(\.id) != apps.map(\.id) else { return }
        apps = fresh
        appCount = fresh.count
        recompute(resetSelection: false)
    }

    private func recompute(resetSelection: Bool) {
        let previousID = selectedItem?.id
        sections = SearchIndex.sections(
            apps: apps,
            query: query,
            history: history,
            providers: providers
        )
        items = sections.flatMap(\.items)
        if !resetSelection, let previousID, let index = items.firstIndex(where: { $0.id == previousID }) {
            selectedIndex = index
        } else {
            selectedIndex = 0
        }
        onRecomputed?()
    }
}
