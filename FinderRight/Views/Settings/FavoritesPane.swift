import SwiftUI
import AppKit
import FinderRightKit

struct FavoritesTab: View {
    @State private var folders = SharedConfig.shared.favoriteFolders
    var body: some View {
        Form {
            Section { PaneHero(pane: .favorites) }
            Section("已收藏") {
                if folders.isEmpty {
                    EmptyStateView(symbol: "folder.badge.plus", title: "还没有常用目录", message: "添加项目目录、下载目录或外接硬盘，减少重复查找。")
                }
                ForEach(folders, id: \.self) { path in
                    let exists = FileManager.default.fileExists(atPath: path)
                    HStack(spacing: Theme.Spacing.m) {
                        AppIconProvider.image(path: path).frame(width: 24, height: 24).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                            Text(verbatim: URL(fileURLWithPath: path).lastPathComponent)
                                .foregroundStyle(exists ? Color.primary : Color.secondary)
                            Text(verbatim: path).font(.system(.callout, design: .monospaced)).foregroundStyle(.secondary)
                                .lineLimit(1).truncationMode(.middle).help(path)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                        if !exists { StatusBadge(kind: .warning, text: "找不到") }
                        RowActionsMenu { actions(path) }
                    }.contextMenu { actions(path) }
                }
                HStack {
                    Spacer()
                    Button {
                        guard let folder = AppDialogs.folder(title: "添加常用目录"), !folders.contains(folder.path) else { return }
                        folders.append(folder.path); SharedConfig.shared.favoriteFolders = folders
                    } label: { Label("添加文件夹…", systemImage: "plus") }
                    .buttonStyle(.bordered)
                }
            }
        }.formStyle(.grouped)
    }
    @ViewBuilder private func actions(_ path: String) -> some View {
        Button("打开") { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
        Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) }
        Button("拷贝路径") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(path, forType: .string)
        }
        Divider()
        Button("移除", role: .destructive) {
            folders.removeAll { $0 == path }; SharedConfig.shared.favoriteFolders = folders
        }
    }
}
