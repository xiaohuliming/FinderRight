import SwiftUI
import AppKit
import FinderRightKit

struct TemplatesTab: View {
    @State private var templates = SharedConfig.shared.customFileTemplates
    @State private var editing: FileTemplate?
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("内置 \(TemplateCatalog.builtIn.count) 种文件类型").font(.headline)
                    Spacer()
                    Button("添加模板", systemImage: "plus") { editing = FileTemplate(name: "新模板", fileExtension: "txt", content: "") }
                }
                Text("自定义文本内容会写入新文件。创建时可以修改文件名。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("自定义模板") {
                if templates.isEmpty { Text("还没有自定义模板。添加常用的 Markdown、代码或配置文件内容。 ").foregroundStyle(.secondary) }
                ForEach(templates) { template in
                    HStack {
                        Image(systemName: "doc.text").foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text(template.name)
                            Text("." + template.fileExtension).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("编辑") { editing = template }
                        Button("移除", role: .destructive) {
                            templates.removeAll { $0.id == template.id }
                            SharedConfig.shared.customFileTemplates = templates
                        }
                    }
                }
            }
            Section("内置类型") {
                Text(TemplateCatalog.builtIn.map { "." + $0.fileExtension }.joined(separator: "   "))
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
            }
        }.formStyle(.grouped).padding()
        .sheet(item: $editing) { template in
            TemplateEditor(template: template) { updated in
                if let index = templates.firstIndex(where: { $0.id == updated.id }) { templates[index] = updated }
                else { templates.append(updated) }
                SharedConfig.shared.customFileTemplates = templates
            }
        }
    }
}

private struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var template: FileTemplate
    var save: (FileTemplate) -> Void
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("文件模板").font(.title2.weight(.semibold))
            TextField("模板名称", text: $template.name)
            TextField("扩展名，例如 md", text: $template.fileExtension)
            Text("初始内容").font(.headline)
            TextEditor(text: $template.content).font(.system(.body, design: .monospaced))
                .frame(height: 230).border(Color(NSColor.separatorColor))
            if let error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("保存") {
                    do {
                        template.name = template.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        template.fileExtension = template.fileExtension.trimmingCharacters(in: CharacterSet(charactersIn: ". "))
                        try FileOperations.validateName(template.name)
                        try FileOperations.validateName(template.fileExtension)
                        guard template.content.utf8.count <= 512_000 else { throw FileOperationError("模板内容不能超过 500 KB。") }
                        save(template); dismiss()
                    } catch { self.error = error.localizedDescription }
                }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 520)
    }
}

struct FavoritesTab: View {
    @State private var folders = SharedConfig.shared.favoriteFolders
    var body: some View {
        Form {
            Section {
                Text("收藏的文件夹会出现在“常用目录”和“复制到 / 移动到”菜单中。")
                    .foregroundStyle(.secondary)
                Button("添加文件夹…", systemImage: "folder.badge.plus") {
                    guard let folder = AppDialogs.folder(title: "添加常用目录"), !folders.contains(folder.path) else { return }
                    folders.append(folder.path); SharedConfig.shared.favoriteFolders = folders
                }
            }
            Section("已收藏") {
                if folders.isEmpty { Text("添加项目目录、下载目录或外接硬盘，减少重复查找。 ").foregroundStyle(.secondary) }
                ForEach(folders, id: \.self) { path in
                    HStack {
                        Image(systemName: "folder").foregroundStyle(.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(URL(fileURLWithPath: path).lastPathComponent)
                            Text(path).font(.caption).foregroundStyle(.secondary).lineLimit(2).help(path)
                        }
                        Spacer()
                        Button("打开") { NSWorkspace.shared.open(URL(fileURLWithPath: path)) }
                        Button("移除", role: .destructive) {
                            folders.removeAll { $0 == path }; SharedConfig.shared.favoriteFolders = folders
                        }
                    }
                }
            }
        }.formStyle(.grouped).padding()
    }
}

struct RecoveryTab: View {
    @State private var pending: [URL] = []
    @State private var legacyCount = 0
    private let operations = FileOperations(stateDirectory: IPCBridge.rootDirectory)
    var body: some View {
        Form {
            Section("安全剪切") {
                Text("点击剪切只记录文件位置，粘贴成功后才移动。再次剪切或取消剪切都不会删除原文件。")
                Text("待粘贴 \(pending.count) 项").font(.headline)
                HStack {
                    Button("选择粘贴位置…") {
                        ActionRunner.submit(IPCRequest(id: UUID().uuidString, action: "pasteFiles", payload: [:]))
                    }.disabled(pending.isEmpty)
                    Button("取消剪切") {
                        ActionRunner.submit(IPCRequest(id: UUID().uuidString, action: "cancelCut", payload: [:]))
                    }.disabled(pending.isEmpty)
                    Button("刷新") { refresh() }
                }
                ForEach(pending, id: \.path) { url in Text(url.path).font(.caption).foregroundStyle(.secondary).textSelection(.enabled) }
            }
            Section("旧版本暂存文件") {
                Text("发现 \(legacyCount) 项暂存内容。旧版尚未粘贴的文件会保留，不会被新剪切清空。")
                Button("打开暂存目录") {
                    NSWorkspace.shared.open(IPCBridge.rootDirectory.appendingPathComponent("staging"))
                }.disabled(legacyCount == 0)
            }
        }.formStyle(.grouped).padding().onAppear { refresh() }
    }
    private func refresh() {
        pending = operations.pendingCuts
        legacyCount = (try? FileManager.default.contentsOfDirectory(atPath: IPCBridge.rootDirectory.appendingPathComponent("staging").path).count) ?? 0
    }
}
