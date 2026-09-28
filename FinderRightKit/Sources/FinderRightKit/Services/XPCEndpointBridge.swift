import Foundation

/// Finder requests use private files and an authenticated Apple Event carrying
/// the request digest. The host verifies the sender's signed code and consumes
/// each bounded request once. There are no network listeners or shared secrets.
public enum IPCBridge {

    /// 共享根目录（在真实用户 home，绕过沙箱重定向）
    public static var rootDirectory: URL {
        let path = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        let home = URL(fileURLWithPath: path)
        return home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("FinderRight", isDirectory: true)
    }

    /// 待处理请求目录
    public static var pendingDir: URL {
        rootDirectory.appendingPathComponent("ipc", isDirectory: true)
    }

    /// 主 App bundle identifier
    public static let mainAppBundleIdentifier = "com.finderright.app"

    /// URL scheme
    public static let urlScheme = "finderright"

    /// 构造 request 文件 URL
    public static func requestFile(id: String) -> URL {
        pendingDir.appendingPathComponent("\(id).req.json")
    }

    /// 构造 response 文件 URL
    public static func responseFile(id: String) -> URL {
        pendingDir.appendingPathComponent("\(id).resp.json")
    }

    /// 确保 pendingDir 存在
    public static func ensureDirectory() throws {
        try SecureRequestStore(directory: rootDirectory).prepare()
        try SecureRequestStore(directory: pendingDir).prepare()
    }
}

// MARK: - 数据结构

/// 一次 IPC 请求的统一信封
public struct IPCRequest: Codable {
    public let id: String
    public let action: String     // 操作类型，如 "createFile" / "moveToTrash" / ...
    public let payload: [String: AnyJSON]  // 参数字典

    public init(id: String, action: String, payload: [String: AnyJSON]) {
        self.id = id
        self.action = action
        self.payload = payload
    }
}

/// 一次 IPC 响应
public struct IPCResponse: Codable {
    public let id: String
    public let success: Bool
    public let message: String?  // 失败时是错误描述；成功时可以是路径等附加信息

    public init(id: String, success: Bool, message: String?) {
        self.id = id
        self.success = success
        self.message = message
    }
}

/// 让 [String: Any] 能 Codable —— 简化版只支持 String / [String] / Bool / Int
public enum AnyJSON: Codable {
    case string(String)
    case stringArray([String])
    case bool(Bool)
    case int(Int)
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([String].self) { self = .stringArray(v); return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Int.self) { self = .int(v); return }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unsupported AnyJSON value")
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .stringArray(let a): try c.encode(a)
        case .bool(let b): try c.encode(b)
        case .int(let i): try c.encode(i)
        case .null: try c.encodeNil()
        }
    }

    public var stringValue: String? { if case let .string(s) = self { return s } else { return nil } }
    public var stringArrayValue: [String]? {
        if case let .stringArray(a) = self { return a } else { return nil }
    }
    public var boolValue: Bool? { if case let .bool(b) = self { return b } else { return nil } }
    public var intValue: Int? { if case let .int(i) = self { return i } else { return nil } }
}
