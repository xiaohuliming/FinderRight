import SwiftUI
import AppKit

struct FullDiskAccessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.s) {
            LabeledContent {
                Button("打开设置…") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                .buttonStyle(.bordered).accessibilityLabel("打开文件访问设置")
            } label: {
                SettingsRowLabel(icon: "folder.badge.gearshape", tint: .blue, title: "文件访问",
                                 subtitle: "仅在受保护目录操作失败时需要")
            }
            Text("应用无法读取此授权状态，请以系统设置为准。")
                .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }
}
