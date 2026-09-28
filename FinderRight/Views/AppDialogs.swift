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
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            Picker("命名方式", selection: $draft.mode) {
                ForEach(RenameMode.allCases, id: \.self) { mode in Text(LocalizedStringKey(mode.rawValue)).tag(mode) }
            }.pickerStyle(.segmented).frame(maxWidth: .infinity)
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.s) {
                GridRow {
                    Text(firstLabel).font(.subheadline).foregroundStyle(.secondary).gridColumnAlignment(.trailing)
                    TextField(firstLabel, text: $draft.first).labelsHidden().frame(maxWidth: .infinity)
                }
                GridRow {
                    if draft.mode != .sequence {
                        Text(secondLabel).font(.subheadline).foregroundStyle(.secondary)
                        TextField(secondLabel, text: $draft.second).labelsHidden().frame(maxWidth: .infinity)
                    } else {
                        Text("起始编号").font(.subheadline).foregroundStyle(.secondary)
                        Stepper("起始编号 \(draft.start)", value: $draft.start, in: 1...999999)
                    }
                }
            }
            previewTable.frame(maxHeight: .infinity)
            Group {
                if let validation = draft.validation {
                    Label(LocalizedStringKey(validation), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                } else {
                    Text("保留扩展名，按当前预览顺序执行。名称冲突时不会覆盖文件。").foregroundStyle(.secondary)
                }
            }
            .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36, alignment: .leading)
        }.padding(Theme.Spacing.xs).frame(width: 560, height: 360)
    }
    private var firstLabel: LocalizedStringKey {
        draft.mode == .affix ? "前缀" : draft.mode == .replace ? "查找" : "名称前缀"
    }
    private var secondLabel: LocalizedStringKey { draft.mode == .affix ? "后缀" : "替换为" }
    private var previewTable: some View {
        VStack(spacing: 0) {
            HStack {
                Text("原名称").frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "arrow.right").foregroundStyle(.tertiary).accessibilityHidden(true)
                Text("新名称").frame(maxWidth: .infinity, alignment: .leading)
            }.font(.subheadline).foregroundStyle(.secondary).padding(.horizontal, Theme.Spacing.s).frame(height: 24)
            Divider()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(draft.urls.enumerated()), id: \.offset) { index, url in
                        let name = draft.names[index]
                        let unchanged = name == url.lastPathComponent
                        HStack {
                            Text(verbatim: url.lastPathComponent).help(url.path)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "arrow.right").foregroundStyle(.tertiary).accessibilityHidden(true)
                            Text(verbatim: name).fontWeight(unchanged ? .regular : .medium).help(name)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(unchanged ? Color.secondary : Color.primary)
                        .lineLimit(1).truncationMode(.middle).padding(.horizontal, Theme.Spacing.s).frame(height: 24)
                        .background(index.isMultiple(of: 2) ? Color.clear : Color.secondary.opacity(0.05))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
    }
}

struct OperationProgressView: View {
    let title: String
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            ProgressView().controlSize(.small).accessibilityLabel("正在处理")
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(LocalizedStringKey(title)).font(.headline)
                Text("正在本机处理，请稍候…").font(.subheadline).foregroundStyle(.secondary)
            }
        }.padding(Theme.Spacing.xl).frame(width: 300)
    }
}

enum AppDialogs {
    private static var progressWindow: NSWindow?
    static func showProgress(_ title: String) {
        let view = OperationProgressView(title: title)
        let window = NSPanel(contentViewController: NSHostingController(rootView: view))
        window.title = "FinderRight"
        window.styleMask = [.titled, .nonactivatingPanel, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
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
            let alert = NSAlert(); alert.messageText = NSLocalizedString(title, comment: "Dialog title"); alert.informativeText = NSLocalizedString(text, comment: "Dialog message")
            alert.addButton(withTitle: String(localized: "好")); alert.runModal()
        }
    }
    static func text(title: String, label: String, initial: String) -> String? {
        onMain {
            activate()
            let alert = NSAlert(); alert.messageText = NSLocalizedString(title, comment: "Dialog title"); alert.informativeText = NSLocalizedString(label, comment: "Field label")
            let field = NSTextField(string: initial); field.frame = NSRect(x: 0, y: 0, width: 360, height: 26)
            field.setAccessibilityLabel(label)
            alert.accessoryView = field; alert.addButton(withTitle: String(localized: "创建")); alert.addButton(withTitle: String(localized: "取消"))
            alert.window.initialFirstResponder = field
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            return field.stringValue
        }
    }
    static func folder(title: String) -> URL? {
        onMain {
            activate()
            let panel = NSOpenPanel(); panel.title = NSLocalizedString(title, comment: "Folder panel title"); panel.prompt = String(localized: "选择")
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
            let alert = NSAlert(); alert.messageText = String(localized: "批量重命名 \(urls.count) 项")
            alert.accessoryView = NSHostingView(rootView: RenamePreview(draft: draft))
            alert.addButton(withTitle: String(localized: "重命名")); alert.addButton(withTitle: String(localized: "取消"))
            guard alert.runModal() == .alertFirstButtonReturn else { return nil }
            return draft.names
        }
    }
}

#Preview("Rename Light") { RenamePreview(draft: RenameDraft(urls: [URL(fileURLWithPath: "/example/notes.md")])).preferredColorScheme(.light) }
#Preview("Rename Dark") { RenamePreview(draft: RenameDraft(urls: [URL(fileURLWithPath: "/example/notes.md")])).preferredColorScheme(.dark) }
#Preview("Progress Light") { OperationProgressView(title: "正在转换图片").preferredColorScheme(.light) }
#Preview("Progress Dark") { OperationProgressView(title: "正在转换图片").preferredColorScheme(.dark) }
