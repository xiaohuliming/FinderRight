import SwiftUI
import AppKit
import FinderRightKit

struct TerminalApp: Identifiable, Hashable {
    let id: String
    let name: String
    let bundleIdentifier: String
    let icon: String

    static let knownTerminals: [TerminalApp] = [
        TerminalApp(id: "terminal", name: "终端", bundleIdentifier: "com.apple.Terminal", icon: "terminal"),
        TerminalApp(id: "iterm", name: "iTerm2", bundleIdentifier: "com.googlecode.iterm2", icon: "terminal.fill"),
        TerminalApp(id: "ghostty", name: "Ghostty", bundleIdentifier: "com.mitchellh.ghostty", icon: "terminal"),
        TerminalApp(id: "warp", name: "Warp", bundleIdentifier: "dev.warp.Warp-Stable", icon: "terminal.fill"),
        TerminalApp(id: "alacritty", name: "Alacritty", bundleIdentifier: "org.alacritty", icon: "terminal.fill"),
        TerminalApp(id: "kitty", name: "Kitty", bundleIdentifier: "net.kovidgoyal.kitty", icon: "terminal.fill"),
    ]
}


struct ToolsTab: View {
    @State private var availableTerminals: [TerminalApp] = []
    @State private var selectedTerminalBundleId: String = "com.apple.Terminal"
    @State private var selectedEditor = SharedConfig.shared.preferredEditor
    private var installedEditors: [KnownEditor] {
        EditorCatalog.all.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil }
    }
    var body: some View {
        Form {
            Section { PaneHero(pane: .tools) }
            Section {
                Picker(selection: Binding(
                    get: { selectedTerminalBundleId },
                    set: { newValue in
                        selectedTerminalBundleId = newValue
                        SharedConfig.shared.preferredTerminal = newValue
                    }
                )) {
                    ForEach(availableTerminals) { terminal in
                        HStack {
                            AppIconProvider.image(bundleID: terminal.bundleIdentifier).accessibilityHidden(true)
                            Text(LocalizedStringKey(terminal.name))
                        }.tag(terminal.bundleIdentifier)
                    }
                } label: {
                    SettingsRowLabel(icon: "terminal.fill", tint: .indigo, title: "默认终端")
                }.pickerStyle(.menu)
            } header: { Text("终端") }
            footer: { Text("选择右键菜单中「打开终端」使用的应用。") }

            Section {
                if installedEditors.isEmpty {
                    Text("未检测到受支持的编辑器。").foregroundStyle(.secondary)
                } else {
                    Picker(selection: $selectedEditor) {
                        ForEach(installedEditors) { editor in
                            HStack {
                                AppIconProvider.image(bundleID: editor.id).accessibilityHidden(true)
                                Text(verbatim: editor.name)
                            }.tag(editor.id)
                        }
                    } label: {
                        SettingsRowLabel(icon: "curlybraces", tint: .indigo, title: "默认编辑器")
                    }
                    .pickerStyle(.menu)
                    .onChange(of: selectedEditor) { SharedConfig.shared.preferredEditor = $0 }
                }
            } header: { Text("系统服务的默认编辑器") }
            footer: { Text("Finder 右键菜单中的“打开编辑器”子菜单可选择任意已安装的编辑器。") }
        }
        .formStyle(.grouped)
        .onAppear {
            detectInstalledApps()
            let savedTerminal = SharedConfig.shared.preferredTerminal
            selectedTerminalBundleId = availableTerminals.contains { $0.bundleIdentifier == savedTerminal }
                ? savedTerminal
                : (availableTerminals.first?.bundleIdentifier ?? "com.apple.Terminal")
            SharedConfig.shared.preferredTerminal = selectedTerminalBundleId
        }
    }
    private func detectInstalledApps() {
        availableTerminals = TerminalApp.knownTerminals.filter { terminal in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) != nil
        }
        if availableTerminals.isEmpty {
            availableTerminals = [TerminalApp.knownTerminals[0]] // System Terminal is always available.
        }
    }
}
