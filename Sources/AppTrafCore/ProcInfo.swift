import Foundation

// proc_pidpath is exported by libSystem (libproc), linked automatically.
@_silgen_name("proc_pidpath")
private func _proc_pidpath(_ pid: Int32, _ buffer: UnsafeMutableRawPointer, _ buffersize: UInt32) -> Int32

public enum ProcInfo {
    private static var cache: [Int32: String] = [:]
    private static let lock = NSLock()

    /// Resolve a stable display name for `pid` — the outermost `.app` (or
    /// `.appex`) bundle name on the executable path, or the binary file name
    /// if no bundle is involved. Returns nil if the path can't be read
    /// (zombie process, permission denied for some root daemons).
    public static func appName(forPID pid: Int32) -> String? {
        lock.lock()
        if let cached = cache[pid] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let bufSize = 4096
        var buf = [CChar](repeating: 0, count: bufSize)
        let n = buf.withUnsafeMutableBytes { ptr -> Int32 in
            _proc_pidpath(pid, ptr.baseAddress!, UInt32(bufSize))
        }
        guard n > 0 else { return nil }
        let path = String(cString: buf)
        let name = deriveAppName(from: path)
        lock.lock()
        cache[pid] = name
        lock.unlock()
        return name
    }

    /// Drop cache entries for PIDs not in the provided set (i.e. processes
    /// that disappeared since the last sample).
    public static func prune(keeping pids: Set<Int32>) {
        lock.lock()
        cache = cache.filter { pids.contains($0.key) }
        lock.unlock()
    }

    private static func deriveAppName(from path: String) -> String {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        for p in parts {
            if p.hasSuffix(".app") { return String(p.dropLast(4)) }
            if p.hasSuffix(".appex") { return String(p.dropLast(6)) }
        }
        return parts.last.map(String.init) ?? path
    }
}
