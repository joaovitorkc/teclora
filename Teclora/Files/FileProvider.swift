import AppKit

private struct FileHit: Equatable {
    let path: String
    let name: String
}

/// Spotlight via `NSMetadataQuery`. Não varre pastas na mão. Teto de 40.
@MainActor
final class FileProvider: CommandProvider {
    private let query = NSMetadataQuery()
    private var results: [FileHit] = []
    private var active = ""
    private var ticket = 0
    private var observer: NSObjectProtocol?
    var onChange: (() -> Void)?

    private let limit = 40

    init() {
        query.searchScopes = [NSMetadataQueryUserHomeScope, NSMetadataQueryLocalComputerScope]
        query.valueListAttributes = [
            NSMetadataItemPathKey,
            NSMetadataItemDisplayNameKey,
            NSMetadataItemFSNameKey,
            NSMetadataItemFSContentChangeDateKey,
        ]
        query.notificationBatchingInterval = 0.3
    }

    func hits(for query: String) -> [LauncherItem] {
        if query != active {
            active = query
            restart(query)
        }
        return results.map(makeItem)
    }

    private func restart(_ text: String) {
        ticket += 1
        let mine = ticket
        query.stop()
        results = []
        guard text.count >= 2 else { return }
        query.predicate = NSPredicate(
            format: "%K CONTAINS[cd] %@ OR %K CONTAINS[cd] %@",
            NSMetadataItemDisplayNameKey, text,
            NSMetadataItemFSNameKey, text
        )
        query.sortDescriptors = [
            NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false),
        ]
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
        observer = NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidFinishGathering,
            object: query,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.collect(mine)
            }
        }
        if !query.start() {
            TecloraLog.error("Spotlight não iniciou a busca")
        }
    }

    private func collect(_ mine: Int) {
        guard mine == ticket else { return }
        query.disableUpdates()
        var found: [FileHit] = []
        let count = min(query.resultCount, limit)
        for index in 0..<count {
            guard let item = query.result(at: index) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String,
                  !path.isEmpty else { continue }
            let name = item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
                ?? (path as NSString).lastPathComponent
            found.append(FileHit(path: path, name: name))
        }
        query.stop()
        guard mine == ticket else { return }
        results = found
        onChange?()
    }

    private func makeItem(_ file: FileHit) -> LauncherItem {
        LauncherItem(
            id: "file.\(file.path)",
            title: file.name,
            subtitle: Self.shortParent(file.path),
            section: "Arquivos",
            action: .openFile(file.path),
            kind: .command(symbol: "doc")
        )
    }

    private static func shortParent(_ path: String) -> String {
        let parent = (path as NSString).deletingLastPathComponent
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if parent.hasPrefix(home) {
            return "~" + parent.dropFirst(home.count)
        }
        return parent
    }
}
