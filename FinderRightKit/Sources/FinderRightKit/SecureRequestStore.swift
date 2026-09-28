import Foundation
import CryptoKit
import Darwin

/// The URL carries a digest authenticated by the sender's Apple Event audit token.
/// Files are only transport; neither a filename nor a caller-supplied PID is trusted.
public struct SecureRequestStore {
    public static let maximumBytes = 1_048_576
    public let directory: URL
    public init(directory: URL) { self.directory = directory }
    public static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    public func prepare() throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        var info = stat()
        guard lstat(directory.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR, info.st_uid == geteuid() else {
            throw FileOperationError("通信目录无效。")
        }
        guard chmod(directory.path, 0o700) == 0 else { throw FileOperationError("无法保护通信目录。") }
    }
    public func write(_ request: IPCRequest) throws -> String {
        guard UUID(uuidString: request.id) != nil else { throw FileOperationError("请求标识无效。") }
        try RequestPolicy.validate(request)
        let data = try JSONEncoder().encode(request)
        guard data.count <= Self.maximumBytes else { throw FileOperationError("请求过大。") }
        try prepare()
        let path = directory.appendingPathComponent(request.id + ".req.json")
        let fd = open(path.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard fd >= 0 else { throw FileOperationError("无法创建请求文件。") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        try handle.write(contentsOf: data)
        try handle.close()
        return Self.digest(data)
    }
    public func consume(id: String, digest: String) throws -> IPCRequest {
        guard UUID(uuidString: id) != nil, digest.count == 64,
              digest.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw FileOperationError("请求标识或摘要无效。")
        }
        let directoryFD = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard directoryFD >= 0 else { throw FileOperationError("通信目录不可用。") }
        defer { close(directoryFD) }
        var directoryInfo = stat()
        guard fstat(directoryFD, &directoryInfo) == 0, directoryInfo.st_uid == geteuid(), directoryInfo.st_mode & 0o077 == 0 else {
            throw FileOperationError("通信目录权限无效。")
        }
        let name = id + ".req.json"
        let fd = openat(directoryFD, name, O_RDONLY | O_NONBLOCK | O_NOFOLLOW | O_CLOEXEC)
        guard fd >= 0 else { throw FileOperationError("请求文件不可用。") }
        let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(fd, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG,
              info.st_uid == geteuid(), info.st_nlink == 1, info.st_size >= 0,
              info.st_size <= Self.maximumBytes, info.st_mode & 0o077 == 0 else {
            throw FileOperationError("请求文件类型、大小或权限无效。")
        }
        let data = try handle.read(upToCount: Self.maximumBytes + 1) ?? Data()
        guard data.count <= Self.maximumBytes, Self.digest(data) == digest else {
            throw FileOperationError("请求内容校验失败。")
        }
        let request = try JSONDecoder().decode(IPCRequest.self, from: data)
        guard request.id == id else { throw FileOperationError("请求标识不匹配。") }
        try RequestPolicy.validate(request)
        guard unlinkat(directoryFD, name, 0) == 0 else { throw FileOperationError("无法消费请求。") }
        return request
    }
}

public enum RequestPolicy {
    public static let terminalIDs: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2", "com.mitchellh.ghostty", "dev.warp.Warp-Stable", "org.alacritty", "net.kovidgoyal.kitty"]
    private static let keys: [String: Set<String>] = [
        "createFile": ["directory", "ext", "content"], "createFolder": ["directory"],
        "cutFiles": ["paths"], "cancelCut": [], "pasteFiles": ["paths", "destination"],
        "copyTo": ["paths", "destination"], "moveTo": ["paths", "destination"], "duplicate": ["paths"],
        "batchRename": ["paths"], "compressZip": ["paths"], "compressTarGz": ["paths"],
        "decompress": ["paths", "archive"], "copyNames": ["paths"], "copyPath": ["paths"],
        "copyFileURLs": ["paths"], "copySHA256": ["paths"],
        "imageConvert": ["paths", "format", "maxPixel"], "imageResize": ["paths", "format", "maxPixel"],
        "imageCompress": ["paths"], "makePDF": ["paths"],
        "openTerminal": ["paths", "directory", "bundleId"], "openWithApp": ["paths", "bundleId"],
        "openFolder": ["directory"], "toggleHiddenFiles": []
    ]
    public static func validate(_ request: IPCRequest) throws {
        guard let allowed = keys[request.action], Set(request.payload.keys).isSubset(of: allowed) else {
            throw FileOperationError("请求包含不支持的操作或参数。")
        }
        let payloadBytes = request.payload.values.reduce(0) { total, value in
            total + (value.stringValue?.utf8.count ?? value.stringArrayValue?.reduce(0) { $0 + $1.utf8.count } ?? 8)
        }
        guard payloadBytes <= SecureRequestStore.maximumBytes else { throw FileOperationError("请求过大。") }
        let requiresPaths: Set<String> = ["cutFiles", "copyTo", "moveTo", "duplicate", "batchRename", "compressZip", "compressTarGz", "copyNames", "copyPath", "copyFileURLs", "copySHA256", "imageConvert", "imageResize", "imageCompress", "makePDF", "openWithApp"]
        if requiresPaths.contains(request.action), request.payload["paths"] == nil {
            throw FileOperationError("缺少文件列表。")
        }
        if ["createFile", "createFolder", "openTerminal", "openFolder"].contains(request.action), request.payload["directory"] == nil {
            throw FileOperationError("缺少目标文件夹。")
        }
        if request.action == "decompress", request.payload["paths"] == nil, request.payload["archive"] == nil {
            throw FileOperationError("缺少压缩文件。")
        }
        func validPath(_ value: String) -> Bool {
            value.hasPrefix("/") && value.utf8.count <= 16_384 && !value.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        }
        for key in ["directory", "destination", "archive"] where request.payload[key] != nil {
            guard let path = request.payload[key]?.stringValue, validPath(path) else { throw FileOperationError("文件路径无效。") }
        }
        if let value = request.payload["paths"] {
            guard let paths = value.stringArrayValue, !paths.isEmpty, paths.count <= 1024, paths.allSatisfy(validPath) else {
                throw FileOperationError("文件列表无效或超过 1024 项。")
            }
        }
        if let ext = request.payload["ext"] {
            guard let text = ext.stringValue, text.utf8.count <= 64, !text.contains("/"), !text.contains(":"),
                  !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains) else { throw FileOperationError("扩展名无效。") }
        }
        if let value = request.payload["content"] {
            guard let text = value.stringValue, text.utf8.count <= 512_000 else { throw FileOperationError("模板内容过大或无效。") }
        }
        if let value = request.payload["maxPixel"] {
            guard let size = value.intValue, (1...16_384).contains(size) else { throw FileOperationError("图片尺寸无效。") }
        }
        if let value = request.payload["format"] {
            guard let format = value.stringValue, ["png", "jpeg", "heic", "tiff"].contains(format) else { throw FileOperationError("图片格式无效。") }
        }
        if request.action == "openTerminal" {
            guard let id = request.payload["bundleId"]?.stringValue, terminalIDs.contains(id) else { throw FileOperationError("终端应用不受支持。") }
        } else if request.action == "openWithApp" {
            guard let id = request.payload["bundleId"]?.stringValue, EditorCatalog.all.contains(where: { $0.id == id }) else { throw FileOperationError("编辑器应用不受支持。") }
        }
    }
}
