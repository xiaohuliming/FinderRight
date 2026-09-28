import Foundation
import AppKit
import FinderRightKit

/// The host performs file operations on the shared background operation queue.
final class FinderRightService {
    private let files = FileOperations(stateDirectory: IPCBridge.rootDirectory)

    func handle(_ request: IPCRequest) -> IPCResponse {
        do {
            let message = try perform(request)
            return IPCResponse(id: request.id, success: true, message: message)
        } catch {
            return IPCResponse(id: request.id, success: false, message: error.localizedDescription)
        }
    }

    private func perform(_ req: IPCRequest) throws -> String? {
        let payload = req.payload
        let paths = (payload["paths"]?.stringArrayValue ?? payload["items"]?.stringArrayValue ?? []).map { URL(fileURLWithPath: $0) }
        func required(_ key: String) throws -> String {
            guard let value = payload[key]?.stringValue, !value.isEmpty else { throw FileOperationError("缺少参数：\(key)") }
            return value
        }
        func reveal(_ urls: [URL]) {
            guard !urls.isEmpty else { return }
            DispatchQueue.main.async { NSWorkspace.shared.activateFileViewerSelecting(urls) }
        }
        switch req.action {
        case "ping": return "ready"
        case "createFile":
            let directory = URL(fileURLWithPath: try required("directory"))
            let ext = payload["ext"]?.stringValue ?? "txt"
            let initial = "untitled" + (ext.isEmpty ? "" : "." + ext)
            guard let name = AppDialogs.text(title: "新建文件", label: "文件名", initial: initial) else { return nil }
            let output = try files.createFile(named: name, content: payload["content"]?.stringValue ?? "", in: directory)
            reveal([output])
        case "createFolder":
            let directory = URL(fileURLWithPath: try required("directory"))
            guard let name = AppDialogs.text(title: "新建文件夹", label: "文件夹名称", initial: "新建文件夹") else { return nil }
            try FileOperations.validateName(name)
            let output = FileOperations.uniqueURL(named: name, in: directory)
            try FileManager.default.createDirectory(at: output, withIntermediateDirectories: false)
            reveal([output])
        case "cutFiles": try files.cut(paths)
        case "cancelCut": try files.cancelCut()
        case "pasteFiles":
            let destination: URL
            if let path = payload["destination"]?.stringValue { destination = URL(fileURLWithPath: path) }
            else if let chosen = AppDialogs.folder(title: "将剪切文件粘贴到…") { destination = chosen }
            else { return nil }
            let result = try files.paste(into: destination)
            reveal(result.completed)
            if !result.succeeded { throw FileOperationError(result.summary) }
        case "copyTo", "moveTo":
            let directory: URL
            if let path = payload["destination"]?.stringValue { directory = URL(fileURLWithPath: path) }
            else if let chosen = AppDialogs.folder(title: req.action == "copyTo" ? "复制到…" : "移动到…") { directory = chosen }
            else { return nil }
            let result = files.transfer(paths, into: directory, move: req.action == "moveTo")
            reveal(result.completed)
            if !result.succeeded { throw FileOperationError(result.summary) }
        case "duplicate":
            for source in paths {
                let result = files.transfer([source], into: source.deletingLastPathComponent(), move: false)
                if !result.succeeded { throw FileOperationError(result.summary) }
                reveal(result.completed)
            }
        case "batchRename":
            guard let names = AppDialogs.rename(paths) else { return nil }
            reveal(try files.rename(paths, names: names))
        case "compressZip", "compressTarGz":
            reveal([try ArchiveOperations.compress(paths, tarGz: req.action == "compressTarGz")])
        case "decompress":
            let archives = paths.isEmpty ? [URL(fileURLWithPath: try required("archive"))] : paths
            var outputs: [URL] = []
            var errors: [String] = []
            for archive in archives {
                do { outputs.append(try ArchiveOperations.extract(archive)) }
                catch { errors.append("\(archive.lastPathComponent)：\(error.localizedDescription)") }
            }
            reveal(outputs)
            if !errors.isEmpty { throw FileOperationError(errors.joined(separator: "\n")) }
        case "copyNames", "copyPath", "copyFileURLs", "copySHA256":
            let text: String
            switch req.action {
            case "copyNames": text = paths.map(\.lastPathComponent).joined(separator: "\n")
            case "copyFileURLs": text = paths.map(\.absoluteString).joined(separator: "\n")
            case "copySHA256": text = try paths.map { try FileOperations.sha256(of: $0) + "  " + $0.lastPathComponent }.joined(separator: "\n")
            default: text = paths.map(\.path).joined(separator: "\n")
            }
            AppDialogs.onMain {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
            }
            if req.action == "copySHA256" { AppDialogs.message(title: "SHA-256 已复制", text: text) }
        case "imageConvert", "imageResize", "imageCompress":
            let format = ImageOperations.Format(rawValue: payload["format"]?.stringValue ?? "png") ?? .png
            let maxPixel = payload["maxPixel"]?.intValue
            var outputs: [URL] = []
            var errors: [String] = []
            for url in paths {
                do {
                    outputs.append(try ImageOperations.convert(url, format: req.action == "imageCompress" ? .jpeg : format,
                        maxPixel: maxPixel, quality: req.action == "imageCompress" ? 0.7 : 0.9))
                } catch { errors.append("\(url.lastPathComponent)：\(error.localizedDescription)") }
            }
            reveal(outputs)
            if !errors.isEmpty { throw FileOperationError(errors.joined(separator: "\n")) }
        case "makePDF": reveal([try ImageOperations.makePDF(paths)])
        case "openTerminal", "openWithApp":
            let bundleId = try required("bundleId")
            guard let applicationURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
                throw FileOperationError("找不到应用，请在设置中重新选择。")
            }
            let urls = req.action == "openTerminal" ? [URL(fileURLWithPath: try required("directory"))] : paths
            DispatchQueue.main.async {
                let configuration = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open(urls, withApplicationAt: applicationURL, configuration: configuration) { _, error in
                    if let error { AppDialogs.message(title: "无法打开应用", text: error.localizedDescription) }
                }
            }
        case "openFolder":
            let url = URL(fileURLWithPath: try required("directory"))
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        case "toggleHiddenFiles":
            guard AXIsProcessTrusted(), let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
                throw FileOperationError("请在系统设置中授予 FinderRight 辅助功能权限，或在 Finder 中按 ⌘⇧. 切换隐藏文件。")
            }
            let source = CGEventSource(stateID: .hidSystemState)
            for down in [true, false] {
                let event = CGEvent(keyboardEventSource: source, virtualKey: 0x2F, keyDown: down)
                event?.flags = [.maskCommand, .maskShift]
                event?.postToPid(finder.processIdentifier)
            }
        default: throw FileOperationError("不支持的操作：\(req.action)")
        }
        return nil
    }
}

/// Finder and Services use the same queue so concurrent requests cannot race.
enum ActionRunner {
    static let queue = DispatchQueue(label: "com.finderright.operations", qos: .userInitiated)
    static func submit(_ request: IPCRequest) {
        queue.async {
            let titles = ["compressZip": "正在压缩", "compressTarGz": "正在压缩", "decompress": "正在解压",
                          "imageConvert": "正在转换图片", "imageResize": "正在缩放图片", "imageCompress": "正在压缩图片",
                          "makePDF": "正在生成 PDF", "copySHA256": "正在计算 SHA-256"]
            let progress = DispatchWorkItem { AppDialogs.showProgress(titles[request.action] ?? "正在处理") }
            if titles[request.action] != nil { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: progress) }
            let result = FinderRightService().handle(request)
            progress.cancel()
            DispatchQueue.main.async { AppDialogs.hideProgress() }
            if !result.success { AppDialogs.message(title: "操作未完成", text: result.message ?? "请重试。") }
        }
    }
}
