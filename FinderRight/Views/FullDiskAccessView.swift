import SwiftUI
import AppKit

struct FullDiskAccessView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("文件访问", systemImage: "folder.badge.gearshape").font(.headline)
            Text("macOS 管理各目录的访问权限。仅在受保护目录操作失败时，按需为 FinderRight 开启完全磁盘访问。")
                .font(.callout).foregroundStyle(.secondary)
            Text("应用无法通过公开 API 准确读取此授权状态，请以系统设置为准。")
                .font(.caption).foregroundStyle(.secondary)
            Button("打开完全磁盘访问设置…") {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
            }
        }.padding().frame(maxWidth: 480, alignment: .leading)
    }
}
