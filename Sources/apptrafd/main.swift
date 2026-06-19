import Foundation
import AppTrafCore

let intervalSec: TimeInterval = 60
let cleanupEverySec: Int64 = 600
let emptySampleStreakLimit = 5

func logLine(_ s: String) {
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(ts)] \(s)")
    fflush(stdout)
}

logLine("apptrafd starting (interval=\(Int(intervalSec))s)")

do {
    try Paths.ensureDataDir()
} catch {
    logLine("ensureDataDir failed: \(error.localizedDescription)")
    exit(1)
}

let db: DB
do {
    db = try DB(path: Paths.dbURL.path)
    logLine("db opened at \(Paths.dbURL.path)")
} catch {
    logLine("db open failed: \(error.localizedDescription)")
    exit(1)
}

var lastCleanup: Int64 = 0
var emptyStreak = 0

while true {
    let now = Int64(Date().timeIntervalSince1970)
    do {
        let entries = try Sampler.sample()
        try db.recordSample(entries, at: now)

        if entries.isEmpty {
            emptyStreak += 1
            if emptyStreak >= emptySampleStreakLimit {
                logLine("got \(emptyStreak) consecutive empty samples — exiting for launchd restart")
                exit(1)
            }
        } else {
            emptyStreak = 0
        }

        if now - lastCleanup > cleanupEverySec {
            try db.cleanup(now: now)
            lastCleanup = now
            logLine("sample ok (\(entries.count) procs) + cleanup")
        }
    } catch {
        logLine("sample failed: \(error.localizedDescription)")
    }
    Thread.sleep(forTimeInterval: intervalSec)
}
