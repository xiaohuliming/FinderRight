import Foundation
import FinderRightKit

/// Consume local requests once and execute asynchronously; dialogs never block Finder.
final class IPCWatcher {
    static let shared = IPCWatcher()
    private init() {}
    func start() { try? IPCBridge.ensureDirectory() }
    func handle(url: URL) {
        guard url.scheme == IPCBridge.urlScheme, url.host == "execute",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
              UUID(uuidString: id) != nil else { return }
        let requestURL = IPCBridge.requestFile(id: id)
        do {
            let values = try requestURL.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .fileSizeKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true, (values.fileSize ?? 0) <= 1_048_576 else {
                throw FileOperationError("请求文件无效。")
            }
            let request = try JSONDecoder().decode(IPCRequest.self, from: Data(contentsOf: requestURL))
            guard request.id == id else { throw FileOperationError("请求标识不匹配。") }
            try FileManager.default.removeItem(at: requestURL)
            ActionRunner.submit(request)
        } catch { AppDialogs.message(title: "无法执行操作", text: error.localizedDescription) }
    }
}
