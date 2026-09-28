import Foundation
import FinderRightKit

final class IPCWatcher {
    static let shared = IPCWatcher()
    private init() {}
    func start() { try? IPCBridge.ensureDirectory() }
    func handle(url: URL, auditToken: Data?) {
        guard url.scheme == IPCBridge.urlScheme, url.host == "execute",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let digest = components.queryItems?.first(where: { $0.name == "sha256" })?.value else { return }
        do {
            try IPCSourceAuthenticator.validate(auditToken)
            let request = try SecureRequestStore(directory: IPCBridge.pendingDir).consume(id: id, digest: digest)
            ActionRunner.submit(request)
        } catch { AppDialogs.message(title: "无法执行操作", text: error.localizedDescription) }
    }
}
