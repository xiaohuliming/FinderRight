import SwiftUI
import AppKit
import FinderRightKit

struct RecoveryTab: View {
    @State private var pending: [URL] = []
    @State private var legacyCount = 0
    private let operations = FileOperations(stateDirectory: IPCBridge.rootDirectory)
    var body: some View {
        Form {
            Section { PaneHero(pane: .recovery) }
            Section {
                if pending.isEmpty {
                    EmptyStateView(symbol: "scissors", title: "没有待粘贴的文件", message: "在 Finder 中右键选择“剪切”后，文件会显示在这里。")
                } else {
                    ForEach(Array(pending.prefix(8)), id: \.path) { url in
                        HStack(spacing: Theme.Spacing.m) {
                            AppIconProvider.image(path: url.path, size: 16).accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                                Text(verbatim: url.lastPathComponent)
                                Text(verbatim: url.deletingLastPathComponent().path)
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .lineLimit(1).truncationMode(.middle).textSelection(.enabled).help(url.path)
                            }
                        }
                    }
                    if pending.count > 8 { Text("还有 \(pending.count - 8) 项").foregroundStyle(.secondary) }
                }
                HStack(spacing: Theme.Spacing.s) {
                    Spacer()
                    Button { refresh() } label: { Image(systemName: "arrow.clockwise") }
                        .buttonStyle(.bordered).help("刷新").accessibilityLabel("刷新待粘贴文件")
                    Button("取消剪切") {
                        ActionRunner.submit(IPCRequest(id: UUID().uuidString, action: "cancelCut", payload: [:]))
                    }.buttonStyle(.bordered).disabled(pending.isEmpty)
                    Button("选择粘贴位置…") {
                        ActionRunner.submit(IPCRequest(id: UUID().uuidString, action: "pasteFiles", payload: [:]))
                    }.buttonStyle(.borderedProminent).disabled(pending.isEmpty)
                }
            } header: { Text("待粘贴，\(pending.count) 项") }

            Section("旧版本暂存") {
                if legacyCount > 0 {
                    LabeledContent {
                        Button("打开暂存目录") {
                            NSWorkspace.shared.open(IPCBridge.rootDirectory.appendingPathComponent("staging"))
                        }.buttonStyle(.bordered)
                    } label: {
                        SettingsRowLabel(icon: "exclamationmark.triangle.fill", tint: .orange,
                                         title: "发现 \(legacyCount) 项旧版暂存内容",
                                         subtitle: "旧版尚未粘贴的文件会保留，不会被新剪切清空。")
                    }
                } else {
                    Label("没有旧版暂存内容", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
        }
        .formStyle(.grouped).onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }
    private func refresh() {
        pending = operations.pendingCuts
        legacyCount = (try? FileManager.default.contentsOfDirectory(atPath: IPCBridge.rootDirectory.appendingPathComponent("staging").path).count) ?? 0
    }
}
