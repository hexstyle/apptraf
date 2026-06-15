import Foundation

public struct ProcEntry: Sendable {
    public let pid: Int32
    public let app: String
    public let bytesIn: UInt64
    public let bytesOut: UInt64

    public init(pid: Int32, app: String, bytesIn: UInt64, bytesOut: UInt64) {
        self.pid = pid
        self.app = app
        self.bytesIn = bytesIn
        self.bytesOut = bytesOut
    }
}

public enum Sampler {
    public static func sample() throws -> [ProcEntry] {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = ["-P", "-L", "1", "-J", "bytes_in,bytes_out", "-x"]
        let out = Pipe()
        let err = Pipe()
        task.standardOutput = out
        task.standardError = err
        try task.run()
        task.waitUntilExit()

        let data = out.fileHandleForReading.readDataToEndOfFile()
        guard let text = String(data: data, encoding: .utf8) else { return [] }

        var result: [ProcEntry] = []
        var seenPIDs = Set<Int32>()
        for raw in text.split(separator: "\n") {
            let cols = raw.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard cols.count >= 3 else { continue }
            let head = cols[0]
            if head.isEmpty { continue }
            if head == "time" { continue }

            guard let dot = head.lastIndex(of: ".") else { continue }
            let fallbackName = String(head[..<dot]).trimmingCharacters(in: .whitespaces)
            let pidStr = String(head[head.index(after: dot)...])
            guard let pid = Int32(pidStr), !fallbackName.isEmpty else { continue }
            guard let bin = UInt64(cols[1]), let bout = UInt64(cols[2]) else { continue }

            let resolved = ProcInfo.appName(forPID: pid) ?? fallbackName
            seenPIDs.insert(pid)
            result.append(ProcEntry(pid: pid, app: resolved, bytesIn: bin, bytesOut: bout))
        }
        ProcInfo.prune(keeping: seenPIDs)
        return result
    }
}
