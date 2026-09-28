import SwiftUI
import AppKit

/// Finder extension discovery can exclude apps launched from temporary build folders.
struct ExtensionSetupHint: View {
    private var needsInstallation: Bool {
        let app = Bundle.main.bundleURL.standardizedFileURL.resolvingSymlinksInPath().path
        let roots = [URL(fileURLWithPath: "/Applications", isDirectory: true),
                     FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
        return !roots.contains { app.hasPrefix($0.standardizedFileURL.resolvingSymlinksInPath().path + "/") }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            if needsInstallation {
                Label("如果系统列表中没有 FinderRight，请先将应用移到“应用程序”文件夹，再从那里重新打开。", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }
            if ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 26 {
                Text("macOS 26 中，请在“文件提供程序”分类查找 FinderRight。")
                    .foregroundStyle(.secondary)
            }
        }.fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Extension Setup Light") { ExtensionSetupHint().padding().preferredColorScheme(.light) }
#Preview("Extension Setup Dark") { ExtensionSetupHint().padding().preferredColorScheme(.dark) }
