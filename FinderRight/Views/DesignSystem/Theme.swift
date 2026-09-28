import SwiftUI
import FinderRightKit

enum Theme {
    enum Spacing {
        static let xxs: CGFloat = 2, xs: CGFloat = 4, s: CGFloat = 8, m: CGFloat = 12
        static let l: CGFloat = 16, xl: CGFloat = 20, xxl: CGFloat = 24, xxxl: CGFloat = 32
    }
    enum Radius {
        static let control: CGFloat = 6
        static let card: CGFloat = 10
        static let panel: CGFloat = 12
        static func tile(_ size: CGFloat) -> CGFloat { size * 0.225 }
    }
    enum Size {
        static let sidebarWidth: CGFloat = 210
        static let headerHeight: CGFloat = 52
        static let sidebarIcon: CGFloat = 20
        static let rowIcon: CGFloat = 26
        static let heroIcon: CGFloat = 52
        static let windowMin = CGSize(width: 780, height: 540)
        static let windowDefault = CGSize(width: 880, height: 620)
        static let windowMax = CGSize(width: 1120, height: 900)
    }
    enum Motion {
        static let quick = Animation.easeInOut(duration: 0.15)
        static let standard = Animation.easeInOut(duration: 0.25)
    }
}

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, menu, templates, favorites, tools, shortcuts, recovery, about
    var id: String { rawValue }
    var title: LocalizedStringKey {
        switch self {
        case .general: return "通用"
        case .menu: return "右键菜单"
        case .templates: return "文件模板"
        case .favorites: return "常用目录"
        case .tools: return "终端与编辑器"
        case .shortcuts: return "快捷键"
        case .recovery: return "剪切与恢复"
        case .about: return "关于"
        }
    }
    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .menu: return "contextualmenu.and.cursorarrow"
        case .templates: return "doc.text.fill"
        case .favorites: return "folder.fill"
        case .tools: return "terminal.fill"
        case .shortcuts: return "keyboard.fill"
        case .recovery: return "scissors"
        case .about: return "info.circle.fill"
        }
    }
    var tint: Color {
        switch self {
        case .general, .about: return .gray
        case .menu: return .blue
        case .templates: return .orange
        case .favorites: return .cyan
        case .tools: return .indigo
        case .shortcuts: return .purple
        case .recovery: return .pink
        }
    }
    var heroDescription: LocalizedStringKey {
        switch self {
        case .general: return "启动方式、图标显示和 Finder 扩展状态。"
        case .menu: return "选择在 Finder 右键菜单中出现的功能，改动立即生效。"
        case .templates: return "新建文件时可选的类型。自定义模板会把内容写入新文件，创建时可以修改文件名。"
        case .favorites: return "收藏的文件夹会出现在“常用目录”和“复制到 / 移动到”菜单中。"
        case .tools: return "右键菜单“打开终端”和系统服务“打开编辑器”使用的应用。"
        case .shortcuts: return "为右键菜单项设置快捷键。在 Finder 中打开右键菜单后按下即可执行，这不是全局热键。"
        case .recovery: return "剪切只记录文件位置，粘贴成功后才移动。再次剪切或取消剪切都不会删除原文件。"
        case .about: return "增强你的 Finder 右键菜单"
        }
    }
}

extension MenuGroup {
    var titleKey: LocalizedStringKey { LocalizedStringKey(rawValue) }
    var tint: Color {
        switch self {
        case .create: return .blue
        case .copy: return .green
        case .files: return .orange
        case .tools: return .indigo
        case .media: return .pink
        }
    }
}
