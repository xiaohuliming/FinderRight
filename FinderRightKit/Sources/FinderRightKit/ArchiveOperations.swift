import Foundation

public enum ArchiveOperations {
    public static let suffixes = [".zip", ".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz", ".tbz2", ".tar.xz", ".txz", ".7z", ".rar"]
    public static func supports(_ url: URL) -> Bool { suffixes.contains { url.lastPathComponent.lowercased().hasSuffix($0) } }

    /// Redirect output to a file so a verbose child cannot block on a full pipe.
    @discardableResult
    public static func run(_ executable: String, arguments: [String], directory: URL? = nil) throws -> String {
        let logURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: logURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: logURL)
        defer { try? handle.close(); try? FileManager.default.removeItem(at: logURL) }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = handle
        process.standardError = handle
        try process.run()
        process.waitUntilExit()
        let output = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
        guard process.terminationStatus == 0 else {
            throw FileOperationError("操作未完成：\(output.suffix(3000))")
        }
        return output
    }

    public static func validateMembers(_ listing: String) throws {
        for member in listing.split(separator: "\n") {
            guard !member.hasPrefix("/"), !member.split(separator: "/").contains("..") else {
                throw FileOperationError("压缩包包含不安全的路径，已停止解压。")
            }
        }
    }

    /// Extract into a new sibling folder; never merge into existing user files.
    public static func extract(_ archive: URL) throws -> URL {
        guard supports(archive) else { throw FileOperationError("不支持此压缩格式。") }
        let listing = try run("/usr/bin/tar", arguments: ["-tf", archive.path])
        try validateMembers(listing)
        let name = archive.deletingPathExtension().lastPathComponent + " 解压"
        let destination = FileOperations.uniqueURL(named: name, in: archive.deletingLastPathComponent())
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        do {
            // bsdtar rejects traversal through symlinks by default. Do not enable -P.
            try run("/usr/bin/tar", arguments: ["-xkf", archive.path, "-C", destination.path, "--no-same-owner", "--no-same-permissions", "--safe-writes"])
        } catch {
            throw FileOperationError(error.localizedDescription + "\n部分解压结果保留在：\(destination.path)")
        }
        return destination
    }

    public static func compress(_ sources: [URL], tarGz: Bool = false) throws -> URL {
        guard let first = sources.first else { throw FileOperationError("请先选择文件。") }
        let directory = first.deletingLastPathComponent()
        guard sources.allSatisfy({ $0.deletingLastPathComponent() == directory }) else {
            throw FileOperationError("请从同一文件夹选择要压缩的文件。")
        }
        let base = sources.count == 1 ? first.lastPathComponent : "Archive"
        let destination = FileOperations.uniqueURL(named: base + (tarGz ? ".tar.gz" : ".zip"), in: directory)
        let names = sources.map { "./" + $0.lastPathComponent }
        do {
            if tarGz { try run("/usr/bin/tar", arguments: ["-czf", destination.path, "--"] + names, directory: directory) }
            else { try run("/usr/bin/zip", arguments: ["-yr", destination.path, "--"] + names, directory: directory) }
        } catch {
            // Only remove the new incomplete archive owned by this operation.
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
        return destination
    }
}
