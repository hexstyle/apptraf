import Foundation

public enum Paths {
    public static var dataDir: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Application Support/AppTraf", isDirectory: true)
    }

    public static var dbURL: URL {
        return dataDir.appendingPathComponent("data.sqlite")
    }

    public static func ensureDataDir() throws {
        try FileManager.default.createDirectory(at: dataDir, withIntermediateDirectories: true)
    }
}

public func humanBytes(_ n: UInt64) -> String {
    if n < 1024 { return "\(n) B" }
    let units = ["KB", "MB", "GB", "TB", "PB"]
    var v = Double(n) / 1024.0
    var i = 0
    while v >= 1024.0 && i < units.count - 1 {
        v /= 1024.0
        i += 1
    }
    return String(format: "%.2f %@", v, units[i])
}
