import Foundation

public enum MenuGroup: String, CaseIterable {
    case create = "新建", copy = "复制信息", files = "文件整理", tools = "开发工具", media = "图片与 PDF"
}

public struct MenuFeature: Identifiable, Equatable {
    public let id: String
    public let nameKey: String
    public let descriptionKey: String
    public let systemImage: String
    public let group: MenuGroup
    public init(id: String, nameKey: String, descriptionKey: String, systemImage: String, group: MenuGroup = .files) {
        self.id = id; self.nameKey = nameKey; self.descriptionKey = descriptionKey; self.systemImage = systemImage; self.group = group
    }
}

public enum MenuFeatureCatalog {
    public static let newFile = "feature.newFile"
    public static let newFolder = "feature.newFolder"
    public static let copyPath = "feature.copyPath"
    public static let copyNames = "feature.copyNames"
    public static let copyFileURLs = "feature.copyFileURLs"
    public static let checksum = "feature.checksum"
    public static let openTerminal = "feature.openTerminal"
    public static let openEditor = "feature.openEditor"
    public static let cut = "feature.cut"
    public static let paste = "feature.paste"
    public static let transfer = "feature.transfer"
    public static let duplicate = "feature.duplicate"
    public static let rename = "feature.rename"
    public static let compress = "feature.compress"
    public static let decompress = "feature.decompress"
    public static let toggleHidden = "feature.toggleHidden"
    public static let favorites = "feature.favorites"
    public static let images = "feature.images"
    public static let pdf = "feature.pdf"

    public static let all: [MenuFeature] = [
        .init(id: newFile, nameKey: "新建文件", descriptionKey: "内置类型和自定义文本模板", systemImage: "doc.badge.plus", group: .create),
        .init(id: newFolder, nameKey: "新建文件夹", descriptionKey: "输入名称后创建文件夹", systemImage: "folder.badge.plus", group: .create),
        .init(id: copyPath, nameKey: "复制路径", descriptionKey: "复制完整路径", systemImage: "doc.on.doc", group: .copy),
        .init(id: copyNames, nameKey: "复制文件名", descriptionKey: "支持一次复制多个名称", systemImage: "textformat", group: .copy),
        .init(id: copyFileURLs, nameKey: "复制文件链接", descriptionKey: "复制 file:// 格式的本地链接", systemImage: "link", group: .copy),
        .init(id: checksum, nameKey: "复制 SHA-256", descriptionKey: "计算文件校验值并复制", systemImage: "number", group: .copy),
        .init(id: cut, nameKey: "剪切", descriptionKey: "粘贴时才移动原文件", systemImage: "scissors"),
        .init(id: paste, nameKey: "粘贴", descriptionKey: "同名自动编号，失败可重试", systemImage: "doc.on.clipboard"),
        .init(id: transfer, nameKey: "复制或移动到", descriptionKey: "选择目标目录或常用目录", systemImage: "folder.badge.arrowshape.right"),
        .init(id: duplicate, nameKey: "创建副本", descriptionKey: "在原目录生成副本", systemImage: "plus.square.on.square"),
        .init(id: rename, nameKey: "批量重命名", descriptionKey: "前后缀、查找替换、编号，执行前预览", systemImage: "pencil"),
        .init(id: compress, nameKey: "压缩", descriptionKey: "创建 ZIP 或 TAR.GZ", systemImage: "archivebox"),
        .init(id: decompress, nameKey: "安全解压", descriptionKey: "每次解压到独立文件夹", systemImage: "archivebox.fill"),
        .init(id: openTerminal, nameKey: "打开终端", descriptionKey: "支持 Terminal、iTerm2、Ghostty 等", systemImage: "terminal", group: .tools),
        .init(id: openEditor, nameKey: "打开编辑器", descriptionKey: "选择已安装的编辑器", systemImage: "curlybraces", group: .tools),
        .init(id: toggleHidden, nameKey: "切换隐藏文件", descriptionKey: "需要辅助功能权限", systemImage: "eye", group: .tools),
        .init(id: favorites, nameKey: "常用目录", descriptionKey: "快速打开收藏的文件夹", systemImage: "star", group: .tools),
        .init(id: images, nameKey: "图片处理", descriptionKey: "格式转换、缩放和 JPEG 压缩，保留原图", systemImage: "photo", group: .media),
        .init(id: pdf, nameKey: "合并为 PDF", descriptionKey: "按文件名顺序合并图片或 PDF", systemImage: "doc.richtext", group: .media),
    ]
}

public enum TemplateCatalog {
    public static let builtIn: [FileTemplate] = [
        .init(id: "txt", name: "文本", fileExtension: "txt", content: ""),
        .init(id: "md", name: "Markdown", fileExtension: "md", content: "# Untitled\n\n"),
        .init(id: "html", name: "HTML", fileExtension: "html", content: "<!doctype html>\n<html lang=\"zh-CN\"><head><meta charset=\"utf-8\"><title>Untitled</title></head><body></body></html>\n"),
        .init(id: "py", name: "Python", fileExtension: "py", content: "#!/usr/bin/env python3\n\n"),
        .init(id: "sh", name: "Shell", fileExtension: "sh", content: "#!/bin/zsh\n\n"),
        .init(id: "json", name: "JSON", fileExtension: "json", content: "{}\n"),
        .init(id: "xml", name: "XML", fileExtension: "xml", content: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<root/>\n"),
        .init(id: "csv", name: "CSV", fileExtension: "csv", content: ""),
        .init(id: "swift", name: "Swift", fileExtension: "swift", content: "import Foundation\n\n"),
        .init(id: "js", name: "JavaScript", fileExtension: "js", content: "\"use strict\";\n"),
        .init(id: "ts", name: "TypeScript", fileExtension: "ts", content: "export {};\n"),
        .init(id: "yaml", name: "YAML", fileExtension: "yaml", content: ""),
        .init(id: "css", name: "CSS", fileExtension: "css", content: ""),
        .init(id: "sql", name: "SQL", fileExtension: "sql", content: "-- SQL\n"),
    ]
}
