import SwiftUI
import FinderRightKit

struct FeatureToggleRow: View {
    let feature: MenuFeature
    @State private var enabled = true

    var body: some View {
        Toggle(isOn: Binding(
            get: { enabled },
            set: { enabled = $0; SharedConfig.shared.setActionEnabled(feature.id, enabled: $0) }
        )) {
            SettingsRowLabel(icon: feature.systemImage, tint: feature.group.tint,
                             title: LocalizedStringKey(feature.nameKey), subtitle: LocalizedStringKey(feature.descriptionKey))
        }.onAppear { enabled = SharedConfig.shared.isActionEnabled(feature.id) }
    }
}
