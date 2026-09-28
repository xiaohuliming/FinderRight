import SwiftUI
import AppKit

struct AboutTab: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                .frame(width: 96, height: 96).accessibilityHidden(true)
            Text("FinderRight").font(.title.weight(.bold))
            Text("版本 \(appVersion)（\(buildNumber)）").font(.subheadline).foregroundStyle(.secondary)
            Text("增强 macOS Finder 右键菜单的强大工具。\n快速访问开发工具、文件操作和自定义动作。")
                .font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true).frame(maxWidth: 360)
            Link("GitHub 仓库", destination: URL(string: "https://github.com/xiaohuliming/FinderRight")!)
                .buttonStyle(.bordered)
            Spacer()
            Text("基于 funny-dog/FinderRight · MIT License").font(.caption).foregroundStyle(.tertiary)
        }.padding(Theme.Spacing.xxl).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
