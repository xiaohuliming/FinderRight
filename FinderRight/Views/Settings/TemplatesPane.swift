import SwiftUI
import FinderRightKit

struct TemplatesTab: View {
    @State private var templates = SharedConfig.shared.customFileTemplates
    @State private var editing: FileTemplate?
    @State private var pendingRemoval: FileTemplate?
    @State private var showRemoval = false

    var body: some View {
        Form {
            Section { PaneHero(pane: .templates) }
            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: Theme.Spacing.s)], spacing: Theme.Spacing.s) {
                    ForEach(TemplateCatalog.builtIn) { template in
                        Text(verbatim: "." + template.fileExtension)
                            .font(.system(.callout, design: .monospaced))
                            .padding(.horizontal, 10).padding(.vertical, Theme.Spacing.xs)
                            .frame(maxWidth: .infinity)
                            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    }
                }.padding(.vertical, Theme.Spacing.xs)
            } header: { Text("内置类型，\(TemplateCatalog.builtIn.count) 种") }

            Section("自定义模板") {
                if templates.isEmpty {
                    EmptyStateView(symbol: "doc.badge.plus", title: "还没有自定义模板", message: "添加常用的 Markdown、代码或配置文件内容。")
                }
                ForEach(templates) { template in
                    HStack {
                        SettingsRowLabel(icon: "doc.text", tint: .orange, title: "\(template.name)", subtitle: detail(template))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        RowActionsMenu { actions(template) }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { editing = template }
                    .contextMenu { actions(template) }
                }
                HStack {
                    Spacer()
                    Button {
                        editing = FileTemplate(name: String(localized: "新模板"), fileExtension: "txt", content: "")
                    } label: { Label("添加模板…", systemImage: "plus") }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(item: $editing) { template in
            TemplateEditor(template: template, isNew: !templates.contains { $0.id == template.id }) { updated in
                if let index = templates.firstIndex(where: { $0.id == updated.id }) { templates[index] = updated }
                else { templates.append(updated) }
                SharedConfig.shared.customFileTemplates = templates
            }
        }
        .confirmationDialog("移除模板“\(pendingRemoval?.name ?? "")”？此操作无法撤销。", isPresented: $showRemoval, titleVisibility: .visible, presenting: pendingRemoval) { template in
            Button("移除", role: .destructive) {
                templates.removeAll { $0.id == template.id }
                SharedConfig.shared.customFileTemplates = templates
            }
            Button("取消", role: .cancel) {}
        }
    }
    private func detail(_ template: FileTemplate) -> LocalizedStringKey {
        if template.content.isEmpty { return ".\(template.fileExtension) · 空文件" }
        return ".\(template.fileExtension) · \(template.content.components(separatedBy: .newlines).count) 行"
    }
    @ViewBuilder private func actions(_ template: FileTemplate) -> some View {
        Button("编辑…") { editing = template }
        Button("移除", role: .destructive) { pendingRemoval = template; showRemoval = true }
    }
}

struct TemplateEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var template: FileTemplate
    var isNew: Bool
    var save: (FileTemplate) -> Void
    @State private var error: String?
    private var usedKB: Int { (template.content.utf8.count + 1023) / 1024 }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.l) {
            Text(isNew ? "新建模板" : "编辑模板").font(.title3.weight(.semibold))
            Grid(alignment: .leading, horizontalSpacing: Theme.Spacing.m, verticalSpacing: Theme.Spacing.m) {
                GridRow {
                    Text("模板名称").gridColumnAlignment(.trailing)
                    TextField("模板名称", text: $template.name).labelsHidden()
                }
                GridRow {
                    Text("扩展名")
                    HStack(spacing: Theme.Spacing.xs) {
                        Text(verbatim: ".").foregroundStyle(.secondary)
                        TextField("扩展名，例如 md", text: $template.fileExtension).labelsHidden()
                    }
                }
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Text("初始内容").font(.body)
                TextEditor(text: $template.content)
                    .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                    .padding(6).frame(height: 240)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
                    .accessibilityLabel("初始内容")
                HStack {
                    Spacer()
                    Text("已用 \(usedKB) KB / 500 KB").font(.subheadline)
                        .foregroundStyle(template.content.utf8.count > 512_000 ? Color.red : Color.secondary)
                }
            }
            HStack(alignment: .center, spacing: Theme.Spacing.s) {
                if let error { Label(LocalizedStringKey(error), systemImage: "exclamationmark.triangle.fill").font(.subheadline).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true) }
                Spacer(minLength: Theme.Spacing.s)
                Button("取消") { dismiss() }.buttonStyle(.bordered).keyboardShortcut(.cancelAction)
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
        }.padding(Theme.Spacing.xxl).frame(width: 560)
    }
}
