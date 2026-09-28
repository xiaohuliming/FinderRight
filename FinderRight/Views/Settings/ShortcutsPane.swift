import SwiftUI
import AppKit
import FinderRightKit

struct ShortcutsTab: View {
    private let actions: [(id: String, name: String, icon: String)] = [
        ("shortcut.copyPath",     "复制路径",       "doc.on.doc"),
        ("shortcut.openTerminal", "打开终端",       "terminal"),
        ("shortcut.cut",          "剪切",           "scissors"),
        ("shortcut.paste",        "粘贴",           "doc.on.clipboard"),
        ("shortcut.compress",     "压缩为 ZIP",     "archivebox"),
        ("shortcut.decompress",   "安全解压", "archivebox.circle"),
        ("shortcut.copyNames", "复制文件名", "textformat"),
        ("shortcut.copyFileURLs", "复制文件链接", "link"),
        ("shortcut.copySHA256", "复制 SHA-256", "number"),
        ("shortcut.batchRename", "批量重命名", "pencil"),
        ("shortcut.duplicate", "创建副本", "plus.square.on.square"),
        ("shortcut.toggleHidden", "切换隐藏文件",   "eye"),
    ]

    var body: some View {
        Form {
            Section { PaneHero(pane: .shortcuts) }
            Section {
                ForEach(actions, id: \.id) { action in
                    ShortcutCell(actionId: action.id, actionName: action.name, actionIcon: action.icon, tint: tint(for: action.id))
                }
            } header: { Text("右键菜单快捷键") }
            footer: { Text("需含 ⌘、⌥ 或 ⌃ 之一。点击按钮后按键录制，Delete 清除，ESC 取消。") }
        }.formStyle(.grouped)
    }
    private func tint(for id: String) -> Color {
        if ["shortcut.copyPath", "shortcut.copyNames", "shortcut.copyFileURLs", "shortcut.copySHA256"].contains(id) { return MenuGroup.copy.tint }
        if ["shortcut.openTerminal", "shortcut.toggleHidden"].contains(id) { return MenuGroup.tools.tint }
        return MenuGroup.files.tint
    }
}

struct ShortcutCell: View {
    let actionId: String
    let actionName: String
    let actionIcon: String
    let tint: Color
    @State private var shortcut: ActionShortcut?
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            SettingsRowLabel(icon: actionIcon, tint: tint, title: LocalizedStringKey(actionName))
                .frame(maxWidth: .infinity, alignment: .leading)
            ShortcutRecorder(keys: shortcut.map { displayString($0).map(String.init) } ?? [], isRecording: isRecording,
                             actionName: LocalizedStringKey(actionName),
                             record: { isRecording ? cancelRecording() : startRecording() },
                             clear: { finishRecording(nil) })
        }
        .onAppear { shortcut = SharedConfig.shared.shortcut(forActionId: actionId) }
        .onDisappear { cancelRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                self.cancelRecording()
            } else if event.keyCode == 51 || event.keyCode == 117 {
                self.finishRecording(nil)
            } else {
                let cleanMods = event.modifierFlags.intersection([.command, .option, .shift, .control])
                guard !cleanMods.intersection([.command, .option, .control]).isEmpty,
                      let chars = event.charactersIgnoringModifiers?.lowercased(),
                      !chars.isEmpty else { return nil }
                self.finishRecording(ActionShortcut(key: chars, modifiers: Int(cleanMods.rawValue)))
            }
            return nil
        }
    }

    private func cancelRecording() { isRecording = false; removeMonitor() }

    private func finishRecording(_ newShortcut: ActionShortcut?) {
        isRecording = false
        shortcut = newShortcut
        SharedConfig.shared.setShortcut(newShortcut, forActionId: actionId)
        removeMonitor()
    }

    private func removeMonitor() {
        if let m = monitor { NSEvent.removeMonitor(m); monitor = nil }
    }

    private func displayString(_ s: ActionShortcut) -> String {
        let flags = NSEvent.ModifierFlags(rawValue: UInt(s.modifiers))
        var r = ""
        if flags.contains(.control) { r += "⌃" }
        if flags.contains(.option)  { r += "⌥" }
        if flags.contains(.shift)   { r += "⇧" }
        if flags.contains(.command) { r += "⌘" }
        r += s.key.uppercased()
        return r
    }
}

struct ShortcutRecorder: View {
    let keys: [String]
    let isRecording: Bool
    let actionName: LocalizedStringKey
    let record: () -> Void
    let clear: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var showClear: Bool { !keys.isEmpty && !isRecording }
    var body: some View {
        HStack(spacing: 2) {
            Button(action: record) {
                Group {
                    if isRecording {
                        HStack(spacing: Theme.Spacing.xs) {
                            Text("请按下快捷键").font(.subheadline)
                            Text(verbatim: "esc").font(.system(size: 11, design: .rounded)).foregroundStyle(.secondary)
                        }
                    } else if keys.isEmpty {
                        Text("点按录制").font(.subheadline).foregroundStyle(.secondary)
                    } else {
                        HStack(spacing: 1) {
                            ForEach(keys.indices, id: \.self) { index in Keycap(keys[index]) }
                        }
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity).contentShape(Rectangle())
            }
            .buttonStyle(.plain).accessibilityLabel(Text(actionName) + Text("快捷键"))
            .accessibilityValue(isRecording ? Text("请按下快捷键") : keys.isEmpty ? Text("未设置") : Text(verbatim: keys.joined()))
            .help("点击录制快捷键，Esc 取消")
            Button(action: clear) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain).help("清除快捷键").accessibilityLabel("清除快捷键")
                .opacity(showClear ? 1 : 0).disabled(!showClear).accessibilityHidden(!showClear).allowsHitTesting(showClear)
                .frame(width: showClear ? 14 : 0).clipped()
        }
        .padding(.horizontal, Theme.Spacing.xs).frame(width: 132, height: 24)
        .background(isRecording ? Color.accentColor.opacity(0.1) : Color(nsColor: .controlBackgroundColor),
                    in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            .stroke(isRecording ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isRecording ? 1.5 : 1))
        .animation(reduceMotion ? nil : Theme.Motion.quick, value: isRecording)
    }
}
