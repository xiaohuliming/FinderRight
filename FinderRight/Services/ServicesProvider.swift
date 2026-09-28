import AppKit
import FinderRightKit

/// Services provides a selection-based fallback in cloud-provider folders.
final class ServicesProvider: NSObject {
    private static var retained: ServicesProvider?
    static func register() {
        let provider = ServicesProvider(); retained = provider
        NSApp.servicesProvider = provider; NSUpdateDynamicServices()
    }
    @objc func performAction(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>?) {
        guard let action = userData else { return }
        let urls: [URL]
        if let paths = pasteboard.propertyList(forType: NSPasteboard.PasteboardType("NSFilenamesPboardType")) as? [String] {
            urls = paths.map { URL(fileURLWithPath: $0) }
        } else {
            urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        }
        guard !urls.isEmpty else { return }
        SharedConfig.shared.reload()
        var payload: [String: AnyJSON] = ["paths": .stringArray(urls.map(\.path))]
        if action == "openTerminal", let first = urls.first {
            let isDirectory = (try? first.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            payload["directory"] = .string((isDirectory ? first : first.deletingLastPathComponent()).path)
            payload["bundleId"] = .string(SharedConfig.shared.preferredTerminal)
        }
        if action == "openWithApp" { payload["bundleId"] = .string(SharedConfig.shared.preferredEditor) }
        if action == "decompress", !urls.allSatisfy(ArchiveOperations.supports) {
            error?.pointee = "请只选择压缩文件。"; return
        }
        if action == "imageConvert" { payload["format"] = .string("png") }
        ActionRunner.submit(IPCRequest(id: UUID().uuidString, action: action, payload: payload), requiresConfirmation: true)
    }
}
