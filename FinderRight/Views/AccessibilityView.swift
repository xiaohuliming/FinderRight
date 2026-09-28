import SwiftUI
import AppKit
import ApplicationServices

struct AccessibilityView: View {
    @State private var hasAccess: Bool = AccessibilityChecker.check()
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.m) {
            LabeledContent {
                StatusBadge(kind: hasAccess ? .success : .warning, text: hasAccess ? "已授权" : "未授权")
                    .accessibilityLabel(hasAccess ? "辅助功能，已授权" : "辅助功能，未授权")
            } label: {
                SettingsRowLabel(icon: "accessibility", tint: .purple, title: "辅助功能", subtitle: "仅“切换隐藏文件”需要")
            }
            if !hasAccess {
                HStack {
                    Spacer()
                    Button("打开设置…") { openAccessibilitySettings() }
                        .accessibilityLabel("打开辅助功能设置")
                    Button("重新检测") { hasAccess = AccessibilityChecker.check() }
                }.buttonStyle(.bordered)
                DisclosureGroup("授权步骤") {
                    VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                        Text("1. 点击上方按钮，会跳转到「辅助功能」列表")
                        Text("2. 找到 FinderRight 并打开开关；如果列表里没有，点 + 添加 FinderRight.app")
                        Text("3. 回到此处点击「重新检测」")
                    }.font(.subheadline).foregroundStyle(.secondary).padding(.top, Theme.Spacing.xs)
                }
            }
        }
        .onAppear { hasAccess = AccessibilityChecker.check() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            hasAccess = AccessibilityChecker.check()
        }
    }
    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

enum AccessibilityChecker {
    static func check() -> Bool {
        // prompt=false：只查询，绝不弹对话框
        let opts = ["AXTrustedCheckOptionPrompt": false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
}

