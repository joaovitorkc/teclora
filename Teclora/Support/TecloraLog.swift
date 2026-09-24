import os

/// Log do processo. Subsystem fixo para o Console.app filtrar `app.teclora`.
enum TecloraLog {
    static let app = Logger(subsystem: "app.teclora", category: "app")

    static func info(_ message: String) {
        app.info("\(message, privacy: .public)")
    }

    static func error(_ message: String) {
        app.error("\(message, privacy: .public)")
    }
}
