import SwiftUI
import FinderRightKit

struct FeaturesTab: View {
    @State private var grouped = SharedConfig.shared.groupedMenus
    var body: some View {
        Form {
            Section { PaneHero(pane: .menu) }
            Section {
                Toggle("按用途分组显示菜单", isOn: $grouped)
                    .onChange(of: grouped) { SharedConfig.shared.groupedMenus = $0 }
            } header: { Text("菜单布局") }
            footer: { Text("关闭后直接显示所有已开启的菜单项。系统“服务”入口可在系统设置的键盘快捷键中管理。") }
            ForEach(MenuGroup.allCases, id: \.self) { group in
                Section {
                    ForEach(MenuFeatureCatalog.all.filter { $0.group == group }) { feature in
                        FeatureToggleRow(feature: feature)
                    }
                } header: { Text(group.titleKey) }
            }
        }.formStyle(.grouped)
    }
}
