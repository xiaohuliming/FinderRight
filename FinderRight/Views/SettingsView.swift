import SwiftUI

struct SettingsView: View {
    @AppStorage("settingsSelectedPane") private var selectedPaneID = SettingsPane.general.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var pane: SettingsPane { SettingsPane(rawValue: selectedPaneID) ?? .general }
    private let sections: [[SettingsPane]] = [[.general], [.menu, .templates, .favorites, .tools, .shortcuts], [.recovery], [.about]]

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                Color.clear.frame(height: Theme.Size.headerHeight)
                List(selection: Binding<SettingsPane?>(
                    get: { pane },
                    set: { if let value = $0 { selectedPaneID = value.rawValue } }
                )) {
                    ForEach(sections.indices, id: \.self) { index in
                        Section {
                            ForEach(sections[index]) { item in
                                HStack(spacing: Theme.Spacing.s) {
                                    IconTile(symbol: item.symbol, tint: item.tint, size: Theme.Size.sidebarIcon, style: .solid)
                                    Text(item.title)
                                }
                                .frame(minHeight: 28).tag(item)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
                .listStyle(.sidebar).scrollContentBackground(.hidden)
            }
            .frame(width: Theme.Size.sidebarWidth)
            .background(VisualEffectBackground(material: .sidebar, blendingMode: .behindWindow).ignoresSafeArea())
            Divider()
            VStack(spacing: 0) {
                HStack {
                    Text(pane.title).font(.headline).accessibilityAddTraits(.isHeader)
                    Spacer()
                }
                .padding(.leading, Theme.Spacing.xl).frame(height: Theme.Size.headerHeight)
                Divider()
                paneContent.id(pane).transition(.opacity)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: Theme.Size.windowMin.width, idealWidth: Theme.Size.windowDefault.width,
               maxWidth: .infinity, minHeight: Theme.Size.windowMin.height,
               idealHeight: Theme.Size.windowDefault.height, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: .top)
        .animation(reduceMotion ? nil : Theme.Motion.quick, value: pane)
    }

    @ViewBuilder private var paneContent: some View {
        switch pane {
        case .general: GeneralTab()
        case .menu: FeaturesTab()
        case .templates: TemplatesTab()
        case .favorites: FavoritesTab()
        case .tools: ToolsTab()
        case .shortcuts: ShortcutsTab()
        case .recovery: RecoveryTab()
        case .about: AboutTab()
        }
    }
}

