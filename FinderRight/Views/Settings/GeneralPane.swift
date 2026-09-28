import SwiftUI
import AppKit
import ServiceManagement
import FinderSync

struct GeneralTab: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = true
    @AppStorage("showDockIcon") private var showDockIcon = false
    @State private var extensionEnabled = FIFinderSyncController.isExtensionEnabled

    var body: some View {
        Form {
            Section { PaneHero(pane: .general) }
            Section {
                LabeledContent {
                    HStack(spacing: Theme.Spacing.s) {
                        StatusBadge(kind: extensionEnabled ? .success : .warning, text: extensionEnabled ? "已启用" : "未启用")
                            .accessibilityLabel(extensionEnabled ? "Finder 扩展，已启用" : "Finder 扩展，未启用")
                        Button("管理扩展…") { FIFinderSyncController.showExtensionManagementInterface() }
                            .buttonStyle(.bordered)
                    }
                } label: {
                    SettingsRowLabel(icon: "puzzlepiece.extension.fill", tint: .blue, title: "FinderRightSync",
                                     subtitle: "在本地目录的右键菜单中显示增强功能")
                }
            } header: { Text("Finder 扩展") }
            footer: {
                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text("云盘目录请使用右键「服务」入口。")
                    ExtensionSetupHint()
                }
            }

            Section {
                Toggle(isOn: Binding(get: { launchAtLogin }, set: { enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() }
                        else { try SMAppService.mainApp.unregister() }
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                        if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
                        loginError = nil
                    } catch { loginError = error.localizedDescription }
                })) {
                    SettingsRowLabel(icon: "power", tint: .gray, title: "开机自动启动", subtitle: "登录时自动运行 FinderRight")
                }
                if let loginError {
                    Label(loginError, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            } header: { Text("启动") }

            Section {
                Toggle(isOn: $showMenuBarIcon) {
                    SettingsRowLabel(icon: "menubar.rectangle", tint: .gray, title: "显示菜单栏图标", subtitle: "关闭后，菜单栏不显示 FinderRight 图标")
                }
                Toggle(isOn: $showDockIcon) {
                    SettingsRowLabel(icon: "dock.rectangle", tint: .gray, title: "显示程序坞图标", subtitle: "关闭后隐藏 Dock 图标，仍可后台运行")
                }
                .onChange(of: showDockIcon) { newValue in
                    if newValue {
                        NSApp.setActivationPolicy(.regular)
                        NSApp.activate(ignoringOtherApps: true)
                    } else {
                        let win = NSApp.keyWindow
                        NSApp.setActivationPolicy(.accessory)
                        DispatchQueue.main.async {
                            win?.makeKeyAndOrderFront(nil)
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
            } header: { Text("显示") }
            footer: {
                if !showMenuBarIcon && !showDockIcon {
                    Label("两个图标都关闭后，可通过 Spotlight 搜索「FinderRight」重新打开偏好设置", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                FullDiskAccessView()
                AccessibilityView()
            } header: { Text("权限") }
            footer: { Text("按需授权即可；图片、文件和配置均在本机处理。") }
        }
        .formStyle(.grouped)
        .onAppear { extensionEnabled = FIFinderSyncController.isExtensionEnabled }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            extensionEnabled = FIFinderSyncController.isExtensionEnabled
        }
    }
}
