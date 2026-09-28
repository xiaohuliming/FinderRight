import Foundation
import AppKit
import FinderRightKit

final class IPCClient {
    static let shared = IPCClient()
    private init() {}
    func send(action: String, payload: [String: AnyJSON]) {
        let id = UUID().uuidString
        do {
            try IPCBridge.ensureDirectory()
            let request = IPCRequest(id: id, action: action, payload: payload)
            let digest = try SecureRequestStore(directory: IPCBridge.pendingDir).write(request)
            guard let url = URL(string: "\(IPCBridge.urlScheme)://execute?id=\(id)&sha256=\(digest)") else { return }
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = false
            NSWorkspace.shared.open(url, configuration: configuration) { _, error in
                if let error { NSLog("FinderRight request could not launch host: %@", error.localizedDescription) }
            }
        } catch { NSLog("FinderRight request failed: %@", error.localizedDescription) }
    }
}
