import SwiftUI
import AppKit

struct IconTile: View {
    enum Style { case solid, soft }
    let symbol: String
    let tint: Color
    var size: CGFloat = Theme.Size.rowIcon
    var style: Style = .soft
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.55, weight: .semibold))
            .foregroundStyle(style == .solid ? Color.white : tint)
            .frame(width: size, height: size)
            .background(style == .solid ? tint : tint.opacity(scheme == .dark ? 0.22 : 0.15),
                        in: RoundedRectangle(cornerRadius: Theme.Radius.tile(size), style: .continuous))
            .accessibilityHidden(true)
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .sidebar
    var blendingMode: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material; view.blendingMode = blendingMode; view.state = .followsWindowActiveState
        return view
    }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material; view.blendingMode = blendingMode
    }
}

struct PaneHero: View {
    let pane: SettingsPane
    var description: LocalizedStringKey?
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            IconTile(symbol: pane.symbol, tint: pane.tint, size: Theme.Size.heroIcon, style: .solid)
            Text(pane.title).font(.title2.weight(.bold)).accessibilityAddTraits(.isHeader)
            Text(description ?? pane.heroDescription).font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.m)
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let tint: Color
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    var body: some View {
        HStack(spacing: Theme.Spacing.m) {
            IconTile(symbol: icon, tint: tint)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title).font(.body)
                if let subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }.accessibilityElement(children: .combine)
    }
}

struct StatusBadge: View {
    enum Kind {
        case success, warning, error
        var color: Color {
            switch self { case .success: return .green; case .warning: return .orange; case .error: return .red }
        }
    }
    let kind: Kind
    let text: LocalizedStringKey
    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            Circle().fill(kind.color).frame(width: 6, height: 6).accessibilityHidden(true)
            Text(text).font(.subheadline)
        }
        .foregroundStyle(kind.color)
        .padding(.horizontal, Theme.Spacing.s).padding(.vertical, 3)
        .background(kind.color.opacity(0.12), in: Capsule())
        .accessibilityElement(children: .ignore).accessibilityLabel(Text(text))
    }
}

struct EmptyStateView: View {
    let symbol: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var body: some View {
        VStack(spacing: Theme.Spacing.s) {
            Image(systemName: symbol).font(.system(size: 28)).foregroundStyle(.tertiary).accessibilityHidden(true)
            Text(title).font(.callout.weight(.medium))
            Text(message).font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }.frame(maxWidth: .infinity).padding(.vertical, Theme.Spacing.xl)
    }
}

struct RowActionsMenu<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        Menu(content: content) {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
        .help("更多操作").accessibilityLabel("更多操作")
    }
}

struct Keycap: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(verbatim: text).font(.system(size: 11, weight: .medium, design: .rounded))
            .frame(minWidth: 20, minHeight: 20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 0, y: 1)
    }
}

enum AppIconProvider {
    private static let cache = NSCache<NSString, NSImage>()
    static func image(bundleID: String, size: CGFloat = 16) -> Image {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return image(path: url.path, size: size)
        }
        return Image(systemName: "app")
    }
    static func image(path: String, size: CGFloat = 24) -> Image {
        let key = "\(path)|\(size)" as NSString
        if let image = cache.object(forKey: key) { return Image(nsImage: image) }
        let source = NSWorkspace.shared.icon(forFile: path)
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        source.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
        image.unlockFocus()
        cache.setObject(image, forKey: key)
        return Image(nsImage: image)
    }
}

#Preview("IconTile Light") { IconTile(symbol: "folder.fill", tint: .cyan).padding().preferredColorScheme(.light) }
#Preview("IconTile Dark") { IconTile(symbol: "folder.fill", tint: .cyan).padding().preferredColorScheme(.dark) }
#Preview("Material Light") { VisualEffectBackground().frame(width: 210, height: 240).preferredColorScheme(.light) }
#Preview("Material Dark") { VisualEffectBackground().frame(width: 210, height: 240).preferredColorScheme(.dark) }
#Preview("Hero Light") { PaneHero(pane: .menu).padding().preferredColorScheme(.light) }
#Preview("Hero Dark") { PaneHero(pane: .menu).padding().preferredColorScheme(.dark) }
#Preview("Row Light") { SettingsRowLabel(icon: "power", tint: .gray, title: "开机自动启动", subtitle: "登录时自动运行 FinderRight").padding().preferredColorScheme(.light) }
#Preview("Row Dark") { SettingsRowLabel(icon: "power", tint: .gray, title: "开机自动启动", subtitle: "登录时自动运行 FinderRight").padding().preferredColorScheme(.dark) }
#Preview("Badge Light") { StatusBadge(kind: .success, text: "已启用").padding().preferredColorScheme(.light) }
#Preview("Badge Dark") { StatusBadge(kind: .warning, text: "未启用").padding().preferredColorScheme(.dark) }
#Preview("Empty Light") { EmptyStateView(symbol: "folder.badge.plus", title: "还没有常用目录", message: "添加项目目录、下载目录或外接硬盘，减少重复查找。").padding().preferredColorScheme(.light) }
#Preview("Empty Dark") { EmptyStateView(symbol: "folder.badge.plus", title: "还没有常用目录", message: "添加项目目录、下载目录或外接硬盘，减少重复查找。").padding().preferredColorScheme(.dark) }
#Preview("Actions Light") { RowActionsMenu { Button("打开") {} }.padding().preferredColorScheme(.light) }
#Preview("Actions Dark") { RowActionsMenu { Button("打开") {} }.padding().preferredColorScheme(.dark) }
#Preview("Keycap Light") { HStack { Keycap("⌘"); Keycap("C") }.padding().preferredColorScheme(.light) }
#Preview("Keycap Dark") { HStack { Keycap("⌘"); Keycap("C") }.padding().preferredColorScheme(.dark) }
#Preview("AppIcon Light") { AppIconProvider.image(bundleID: "com.apple.finder", size: 24).padding().preferredColorScheme(.light) }
#Preview("AppIcon Dark") { AppIconProvider.image(bundleID: "com.apple.finder", size: 24).padding().preferredColorScheme(.dark) }
