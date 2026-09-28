import AppKit
import SwiftUI
import FinderRightKit

final class RenameDraft: ObservableObject {
    let urls: [URL]
    @Published var mode: RenameMode = .affix
    @Published var first = ""
    @Published var second = ""
    @Published var start = 1
    init(urls: [URL]) { self.urls = urls }
    var names: [String] { RenamePlan.names(for: urls, mode: mode, first: first, second: second, start: start) }
    var validation: String? {
        do {
            for name in names { try FileOperations.validateName(name) }
            guard Set(names.map { $0.lowercased() }).count == names.count else { return "新名称存在重复。" }
            return nil
        } catch { return error.localizedDescription }
    }
}

struct RenamePreview: View {
    @ObservedObject var draft: RenameDraft
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("命名方式", selection: $draft.mode) {
                ForEach(RenameMode.allCases, id: \.self) { mode in Text(mode.rawValue).tag(mode) }
            }.pickerStyle(.segmented)
            HStack {
                TextField(draft.mode == .affix ? "前缀" : draft.mode == .replace ? "查找" : "名称前缀", text: $draft.first)
                if draft.mode != .sequence { TextField(draft.mode == .affix ? "后缀" : "替换为", text: $draft.second) }
                else { Stepper("起始编号 \(draft.start)", value: $draft.start, in: 1...999999) }
            }
            Text("保留扩展名，按当前预览顺序执行。名称冲突时不会覆盖文件。")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Text("原名称"); Spacer(); Text("新名称") }.font(.caption).foregroundStyle(.secondary)
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(Array(draft.urls.enumerated()), id: \.offset) { index, url in
                        HStack {
                            Text(url.lastPathComponent).lineLimit(1).help(url.path).frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundStyle(.secondary)
                            Text(draft.names[index]).lineLimit(1).help(draft.names[index]).frame(maxWidth: .infinity, alignment: .leading)
                        }.font(.system(.body, design: .monospaced))
                        Divider()
                    }
                }
            }.frame(height: 190)
            if let validation = draft.validation { Label(validation, systemImage: "exclamationmark.triangle").foregroundStyle(.red).font(.caption) }
        }.padding(4).frame(width: 540, height: 330)
    }
}

enum AppDialogs {
    private static var progressWindow: NSWindow?
    static func showProgress(_ title: String) {
        let view = VStack(spacing: 14) {
            ProgressView().controlSize(.small)
            Text(title).font(.headline)
            Text("正在本机处理，请稍候…").font(.caption).foregroundStyle(.secondary)
        }.padding(28).frame(width: 280)
        let window = NSPanel(contentViewController: NSHostingController(rootView: view))
        window.title = "FinderRight"
        window.styleMask = [.titled, .nonactivatingPanel]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center(); window.orderFrontRegardless()
        progressWindow = window
    }
    static func hideProgress() { progressWindow?.close(); progressWindow = nil }
    static func onMain<T>(_ action: () -> T) -> T {
        Thread.isMainThread ? action() : DispatchQueue.main.sync(execute: action)
    }
    private static func activate() { NSApp.activate(ignoringOtherApps: true) }
    static func message(title: String, text: String) {
        DispatchQueue.main.async {
            activate()
            let alert = NSAlert(); alert.messageText = title; alert.informativeText = text
            alert.addButton(withTitle: "好"); alert.runModal()
        }
    }
    static func text(title: String, label: String, initial: String) -> String? {
        onMain {
            activate()
            let alert = NSAlert(); alert.messageText = title; alert.informativeText = label
            let field = NSTextField(string: initial); field.frame = NSRect(x: 0, y: 0, width: 360, height: 26)
            field.setAccessibilityLabel(label)
            alert.accessoryView = field; alert.addButton(withTitle: "创建"); alert.addButton(withTitle: "取消")
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            return field.stringValue
        }
    }
    static func folder(title: String) -> URL? {
        onMain {
            activate()
            let panel = NSOpenPanel(); panel.title = title; panel.prompt = "选择"
            panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.allowsMultipleSelection = false
            panel.canCreateDirectories = true
            return panel.runModal() == .OK ? panel.url : nil
        }
    }
    static func rename(_ urls: [URL]) -> [String]? {
        guard !urls.isEmpty else { return nil }
        return onMain {
            activate()
            let draft = RenameDraft(urls: urls)
            let alert = NSAlert(); alert.messageText = "批量重命名 \(urls.count) 项"
            alert.accessoryView = NSHostingView(rootView: RenamePreview(draft: draft))
            alert.addButton(withTitle: "重命名"); alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            return draft.names
        }
    }
}
