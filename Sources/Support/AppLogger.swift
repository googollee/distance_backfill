import os

enum AppLogger {
    private static let subsystem = "im.googol.DistanceBackfill"

    static let sync = Logger(subsystem: subsystem, category: "sync")
    static let observer = Logger(subsystem: subsystem, category: "observer")
    static let undo = Logger(subsystem: subsystem, category: "undo")
}
