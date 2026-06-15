import Foundation
import SQLite3

private let SQLITE_TRANSIENT_SWIFT = unsafeBitCast(
    OpaquePointer(bitPattern: -1),
    to: sqlite3_destructor_type.self
)

public struct AggRow: Sendable {
    public let app: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64
}

public final class DB {
    private var handle: OpaquePointer?

    public init(path: String) throws {
        if sqlite3_open(path, &handle) != SQLITE_OK {
            let msg = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            throw NSError(domain: "AppTraf.DB", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "sqlite3_open: \(msg)"])
        }
        try exec("PRAGMA journal_mode=WAL;")
        try exec("PRAGMA synchronous=NORMAL;")
        try exec("""
            CREATE TABLE IF NOT EXISTS samples (
                hour INTEGER NOT NULL,
                app TEXT NOT NULL,
                bytes_in INTEGER NOT NULL DEFAULT 0,
                bytes_out INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY (hour, app)
            );
        """)
        try exec("CREATE INDEX IF NOT EXISTS idx_samples_hour ON samples(hour);")
        try exec("""
            CREATE TABLE IF NOT EXISTS process_state (
                pid INTEGER NOT NULL,
                app TEXT NOT NULL,
                last_in INTEGER NOT NULL,
                last_out INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY (pid, app)
            );
        """)
    }

    deinit {
        if let h = handle { sqlite3_close(h) }
    }

    public func exec(_ sql: String) throws {
        var errPtr: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(handle, sql, nil, nil, &errPtr) != SQLITE_OK {
            let msg = errPtr.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errPtr)
            throw NSError(domain: "AppTraf.DB", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "sqlite3_exec: \(msg)"])
        }
    }

    public func recordSample(_ entries: [ProcEntry], at now: Int64) throws {
        let hour = (now / 3600) * 3600

        try exec("BEGIN;")
        var committed = false
        defer {
            if !committed { _ = try? exec("ROLLBACK;") }
        }

        for e in entries {
            var stmt: OpaquePointer?

            let sel = "SELECT last_in, last_out FROM process_state WHERE pid=? AND app=?;"
            sqlite3_prepare_v2(handle, sel, -1, &stmt, nil)
            sqlite3_bind_int(stmt, 1, e.pid)
            sqlite3_bind_text(stmt, 2, e.app, -1, SQLITE_TRANSIENT_SWIFT)
            var deltaIn: UInt64 = 0
            var deltaOut: UInt64 = 0
            var hasPrior = false
            if sqlite3_step(stmt) == SQLITE_ROW {
                let lastIn = UInt64(bitPattern: sqlite3_column_int64(stmt, 0))
                let lastOut = UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
                deltaIn = e.bytesIn > lastIn ? e.bytesIn - lastIn : 0
                deltaOut = e.bytesOut > lastOut ? e.bytesOut - lastOut : 0
                hasPrior = true
            }
            sqlite3_finalize(stmt)
            stmt = nil

            let up = """
                INSERT INTO process_state(pid, app, last_in, last_out, updated_at)
                VALUES(?, ?, ?, ?, ?)
                ON CONFLICT(pid, app) DO UPDATE SET
                    last_in = excluded.last_in,
                    last_out = excluded.last_out,
                    updated_at = excluded.updated_at;
            """
            sqlite3_prepare_v2(handle, up, -1, &stmt, nil)
            sqlite3_bind_int(stmt, 1, e.pid)
            sqlite3_bind_text(stmt, 2, e.app, -1, SQLITE_TRANSIENT_SWIFT)
            sqlite3_bind_int64(stmt, 3, Int64(bitPattern: e.bytesIn))
            sqlite3_bind_int64(stmt, 4, Int64(bitPattern: e.bytesOut))
            sqlite3_bind_int64(stmt, 5, now)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            stmt = nil

            if hasPrior && (deltaIn > 0 || deltaOut > 0) {
                let ins = """
                    INSERT INTO samples(hour, app, bytes_in, bytes_out)
                    VALUES(?, ?, ?, ?)
                    ON CONFLICT(hour, app) DO UPDATE SET
                        bytes_in = bytes_in + excluded.bytes_in,
                        bytes_out = bytes_out + excluded.bytes_out;
                """
                sqlite3_prepare_v2(handle, ins, -1, &stmt, nil)
                sqlite3_bind_int64(stmt, 1, hour)
                sqlite3_bind_text(stmt, 2, e.app, -1, SQLITE_TRANSIENT_SWIFT)
                sqlite3_bind_int64(stmt, 3, Int64(bitPattern: deltaIn))
                sqlite3_bind_int64(stmt, 4, Int64(bitPattern: deltaOut))
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
        }

        try exec("COMMIT;")
        committed = true
    }

    public func cleanup(now: Int64, retentionHours: Int = 168, stateTTLSeconds: Int = 300) throws {
        let cutHour = ((now - Int64(retentionHours) * 3600) / 3600) * 3600
        let cutState = now - Int64(stateTTLSeconds)
        try exec("DELETE FROM samples WHERE hour < \(cutHour);")
        try exec("DELETE FROM process_state WHERE updated_at < \(cutState);")
    }

    public func aggregate(fromHour: Int64, toHour: Int64) throws -> [AggRow] {
        var rows: [AggRow] = []
        var stmt: OpaquePointer?
        let sql = """
            SELECT app, SUM(bytes_in), SUM(bytes_out)
            FROM samples
            WHERE hour >= ? AND hour <= ?
            GROUP BY app
            ORDER BY (SUM(bytes_in) + SUM(bytes_out)) DESC;
        """
        sqlite3_prepare_v2(handle, sql, -1, &stmt, nil)
        sqlite3_bind_int64(stmt, 1, fromHour)
        sqlite3_bind_int64(stmt, 2, toHour)
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let cApp = sqlite3_column_text(stmt, 0) else { continue }
            let app = String(cString: cApp)
            let bi = UInt64(bitPattern: sqlite3_column_int64(stmt, 1))
            let bo = UInt64(bitPattern: sqlite3_column_int64(stmt, 2))
            rows.append(AggRow(app: app, bytesIn: bi, bytesOut: bo))
        }
        sqlite3_finalize(stmt)
        return rows
    }
}
