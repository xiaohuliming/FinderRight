import Foundation
import CryptoKit

public struct FileOperationError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct BatchResult {
    public var completed: [URL] = []
    public var failures: [String] = []
    public var succeeded: Bool { failures.isEmpty }
    public var summary: String {
        "已完成 \(completed.count) 项" + (failures.isEmpty ? "" : "\n" + failures.joined(separator: "\n"))
    }
}

/// All mutations share one lock across Services and Finder IPC within the host app.
public final class FileOperations {
    private static let lock = NSRecursiveLock()
    private let fm = FileManager.default
    public let stateDirectory: URL
    public var queueURL: URL { stateDirectory.appendingPathComponent("cut-queue.json") }

    public init(stateDirectory: URL) { self.stateDirectory = stateDirectory }

    private func locked<T>(_ work: () throws -> T) rethrows -> T {
        Self.lock.lock()
        defer { Self.lock.unlock() }
        return try work()
    }

    public var pendingCuts: [URL] {
        guard let data = try? Data(contentsOf: queueURL),
              let paths = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return paths.map { URL(fileURLWithPath: $0) }
    }

    private func saveQueue(_ urls: [URL]) throws {
        try fm.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(urls.map(\.path)).write(to: queueURL, options: .atomic)
    }

    /// Cutting only records source paths. The source remains untouched until paste.
    public func cut(_ sources: [URL]) throws {
        try locked {
            guard !sources.isEmpty else { throw FileOperationError("请先选择文件。") }
            let legacy = stateDirectory.appendingPathComponent("staging").standardizedFileURL.path + "/"
            if pendingCuts.contains(where: { $0.standardizedFileURL.path.hasPrefix(legacy) && fm.fileExists(atPath: $0.path) }) {
                throw FileOperationError("旧版本暂存区仍有文件，请先粘贴到安全目录，再开始新的剪切。")
            }
            for url in sources where !fm.fileExists(atPath: url.path) {
                throw FileOperationError("文件不存在：\(url.lastPathComponent)")
            }
            try saveQueue(Array(Set(sources)).sorted { $0.path < $1.path })
        }
    }

    public func cancelCut() throws {
        try locked {
            let legacy = stateDirectory.appendingPathComponent("staging").standardizedFileURL.path + "/"
            guard !pendingCuts.contains(where: { $0.standardizedFileURL.path.hasPrefix(legacy) }) else {
                throw FileOperationError("请先粘贴旧版本暂存文件，以免失去恢复入口。")
            }
            try saveQueue([])
        }
    }

    public func paste(into directory: URL) throws -> BatchResult {
        try locked {
            let sources = pendingCuts
            guard !sources.isEmpty else { throw FileOperationError("没有待粘贴的文件。") }
            var result = BatchResult()
            var remaining: [URL] = []
            for source in sources {
                do { result.completed.append(try transferOne(source, into: directory, move: true)) }
                catch { remaining.append(source); result.failures.append("\(source.lastPathComponent)：\(error.localizedDescription)") }
            }
            // A failed move remains retryable, including an old-version staged file.
            try saveQueue(remaining)
            return result
        }
    }

    public func transfer(_ sources: [URL], into directory: URL, move: Bool) -> BatchResult {
        locked {
            var result = BatchResult()
            for source in sources {
                do { result.completed.append(try transferOne(source, into: directory, move: move)) }
                catch { result.failures.append("\(source.lastPathComponent)：\(error.localizedDescription)") }
            }
            return result
        }
    }

    private func transferOne(_ source: URL, into directory: URL, move: Bool) throws -> URL {
        let from = source.standardizedFileURL.resolvingSymlinksInPath()
        let to = directory.standardizedFileURL.resolvingSymlinksInPath()
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: to.path, isDirectory: &isDir), isDir.boolValue else {
            throw FileOperationError("目标文件夹不存在。")
        }
        guard fm.fileExists(atPath: source.path) else { throw FileOperationError("源文件不存在。") }
        guard to != from, !to.path.hasPrefix(from.path + "/") else {
            throw FileOperationError("不能把文件夹放进自身或其子文件夹。")
        }
        if move && source.deletingLastPathComponent().standardizedFileURL.resolvingSymlinksInPath() == to {
            return source
        }
        let destination = Self.uniqueURL(named: source.lastPathComponent, in: directory)
        if move { try fm.moveItem(at: source, to: destination) }
        else { try fm.copyItem(at: source, to: destination) }
        return destination
    }

    public static func uniqueURL(named name: String, in directory: URL) -> URL {
        let fm = FileManager.default
        var url = directory.appendingPathComponent(name)
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        var index = 2
        while fm.fileExists(atPath: url.path) || (try? fm.destinationOfSymbolicLink(atPath: url.path)) != nil {
            let numbered = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            url = directory.appendingPathComponent(numbered)
            index += 1
        }
        return url
    }

    public static func validateName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name != ".", name != "..", !name.contains("/"), !name.contains(":"),
              !name.contains("\0"), name.utf8.count <= 255 else {
            throw FileOperationError("名称不能为空，不能包含 /、: 或控制字符，且不能超过 255 字节。")
        }
        guard name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else {
            throw FileOperationError("名称不能包含控制字符。")
        }
    }

    public func createFile(named name: String, content: String, in directory: URL) throws -> URL {
        try locked {
            try Self.validateName(name)
            let url = Self.uniqueURL(named: name, in: directory)
            try Data(content.utf8).write(to: url, options: .withoutOverwriting)
            return url
        }
    }

    public func rename(_ sources: [URL], names: [String]) throws -> [URL] {
        try locked {
            guard sources.count == names.count, !sources.isEmpty else { throw FileOperationError("重命名参数不完整。") }
            let destinations = zip(sources, names).map { $0.deletingLastPathComponent().appendingPathComponent($1) }
            for name in names { try Self.validateName(name) }
            let folded = destinations.map { $0.standardizedFileURL.path.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) }
            guard Set(folded).count == folded.count else { throw FileOperationError("新名称之间存在冲突，请修改后重试。") }
            for (source, destination) in zip(sources, destinations) {
                guard fm.fileExists(atPath: source.path) else { throw FileOperationError("源文件不存在：\(source.lastPathComponent)") }
                if source != destination && fm.fileExists(atPath: destination.path) {
                    throw FileOperationError("目标名称已存在：\(destination.lastPathComponent)")
                }
            }
            var moved: [(URL, URL)] = []
            do {
                for (source, destination) in zip(sources, destinations) where source != destination {
                    try fm.moveItem(at: source, to: destination)
                    moved.append((source, destination))
                }
            } catch {
                var recovery: [String] = []
                for (source, destination) in moved.reversed() {
                    do { try fm.moveItem(at: destination, to: source) }
                    catch { recovery.append(destination.path) }
                }
                throw FileOperationError(error.localizedDescription + (recovery.isEmpty ? "\n已恢复原名称。" : "\n以下文件保留新名称：\n" + recovery.joined(separator: "\n")))
            }
            return destinations
        }
    }

    public static func sha256(of file: URL) throws -> String {
        guard (try file.resourceValues(forKeys: [.isRegularFileKey])).isRegularFile == true else {
            throw FileOperationError("校验值仅支持普通文件。")
        }
        let handle = try FileHandle(forReadingFrom: file)
        defer { try? handle.close() }
        var hash = SHA256()
        while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty { hash.update(data: data) }
        return hash.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

public enum RenameMode: String, CaseIterable {
    case affix = "添加前后缀", replace = "查找替换", sequence = "编号命名"
}

public enum RenamePlan {
    public static func names(for urls: [URL], mode: RenameMode, first: String, second: String, start: Int = 1) -> [String] {
        urls.enumerated().map { index, url in
            let ext = url.pathExtension
            let base = ext.isEmpty ? url.lastPathComponent : url.deletingPathExtension().lastPathComponent
            let stem: String
            switch mode {
            case .affix: stem = first + base + second
            case .replace: stem = first.isEmpty ? base : base.replacingOccurrences(of: first, with: second)
            case .sequence: stem = first + String(format: "%03d", start + index)
            }
            return ext.isEmpty ? stem : stem + "." + ext
        }
    }
}
