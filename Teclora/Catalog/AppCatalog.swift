import AppKit

enum AppCatalog {
    /// Varre as pastas de apps. Não toca em UI: pode rodar fora da main thread.
    static func load(excluding selfID: String?) -> [InstalledApp] {
        var seenIDs = Set<String>()
        var seenPaths = Set<String>()
        var apps: [InstalledApp] = []

        for directory in searchDirectories {
            for folder in [directory, directory.appendingPathComponent("Utilities")] {
                appendApps(
                    in: folder,
                    selfID: selfID,
                    seenIDs: &seenIDs,
                    seenPaths: &seenPaths,
                    into: &apps
                )
            }
        }

        apps.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        return apps
    }

    private static var searchDirectories: [URL] {
        let homeApps = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications")
        return [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            homeApps,
        ]
    }

    private static func appendApps(
        in directory: URL,
        selfID: String?,
        seenIDs: inout Set<String>,
        seenPaths: inout Set<String>,
        into apps: inout [InstalledApp]
    ) {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for url in contents where url.pathExtension == "app" {
            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { continue }

            let bundle = Bundle(url: url)
            let bundleID = bundle?.bundleIdentifier
            if let bundleID {
                if bundleID == selfID { continue }
                if !seenIDs.insert(bundleID).inserted { continue }
            }

            apps.append(
                InstalledApp(
                    id: path,
                    name: localizedName(for: url, bundle: bundle),
                    fileName: url.deletingPathExtension().lastPathComponent,
                    bundleID: bundleID,
                    url: url
                )
            )
        }
    }

    private static func localizedName(for url: URL, bundle: Bundle?) -> String {
        if let bundle {
            let keys = ["CFBundleDisplayName", "CFBundleName"]
            for dict in [bundle.localizedInfoDictionary, bundle.infoDictionary] {
                guard let dict else { continue }
                for key in keys {
                    if let name = dict[key] as? String, !name.isEmpty {
                        return name
                    }
                }
            }
        }
        return FileManager.default.displayName(atPath: url.path)
    }
}

/// Ícones sob demanda, com cache. Evita carregar ~200 ícones a cada abertura.
@MainActor
enum AppIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(for app: InstalledApp) -> NSImage {
        if let cached = cache[app.id] { return cached }
        let icon = NSWorkspace.shared.icon(forFile: app.id)
        icon.size = NSSize(width: 64, height: 64)
        cache[app.id] = icon
        return icon
    }
}
