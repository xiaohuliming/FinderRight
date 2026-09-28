import SwiftUI
import FinderSync
import FinderRightKit

struct OnboardingView: View {
    var onClose: () -> Void = {}
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0
    @State private var movingForward = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let totalSteps = 3

    private var pageTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .asymmetric(
            insertion: .move(edge: movingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: movingForward ? .leading : .trailing).combined(with: .opacity))
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    switch currentStep {
                    case 0: WelcomeStep()
                    case 1: EnableExtensionStep()
                    default: CompletionStep()
                    }
                }.id(currentStep).transition(pageTransition)
            }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            Divider()
            HStack {
                HStack(spacing: Theme.Spacing.s) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(index == currentStep ? Color.accentColor : Color(nsColor: .tertiaryLabelColor))
                            .frame(width: index == currentStep ? 18 : 6, height: 6)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("第 \(currentStep + 1) 步，共 \(totalSteps) 步"))
                Spacer()
                Button("上一步") {
                    movingForward = false
                    withAnimation(Theme.Motion.standard) { currentStep -= 1 }
                }
                .buttonStyle(.bordered).opacity(currentStep > 0 ? 1 : 0)
                .disabled(currentStep == 0).accessibilityHidden(currentStep == 0)
                if currentStep < totalSteps - 1 {
                    Button("下一步") {
                        movingForward = true
                        withAnimation(Theme.Motion.standard) { currentStep += 1 }
                    }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                } else {
                    Button("开始使用") {
                        hasCompletedOnboarding = true
                        onClose()
                    }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, Theme.Spacing.xxl).frame(height: 60)
            .animation(reduceMotion ? nil : Theme.Motion.quick, value: currentStep)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 640, height: 520)
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.m) {
            Spacer(minLength: Theme.Spacing.s)
            Image(nsImage: NSApp.applicationIconImage).resizable().scaledToFit()
                .frame(width: 80, height: 80).accessibilityHidden(true)
            Text("欢迎使用 FinderRight").font(.largeTitle.weight(.bold))
            Text("增强你的 Finder 右键菜单").font(.title3).foregroundStyle(.secondary)
            VStack(spacing: 0) {
                feature("cursorarrow.click.2", tint: .blue, title: "常用操作一步到位", detail: "新建文件、复制路径、打开终端或编辑器")
                Divider().padding(.leading, 56)
                feature("checkmark.shield.fill", tint: .green, title: "安全的文件整理", detail: "剪切粘贴不丢文件，重命名先预览，解压不越界")
                Divider().padding(.leading, 56)
                feature("photo.fill", tint: .pink, title: "图片与 PDF", detail: "格式转换、缩放压缩、合并为 PDF，均在本机处理")
            }.modifier(OnboardingCard()).padding(.top, Theme.Spacing.s)
            Spacer(minLength: Theme.Spacing.s)
        }.padding(.horizontal, Theme.Spacing.xxxl).padding(.vertical, Theme.Spacing.m)
    }
    private func feature(_ symbol: String, tint: Color, title: LocalizedStringKey, detail: LocalizedStringKey) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            IconTile(symbol: symbol, tint: tint, size: 28, style: .solid)
            VStack(alignment: .leading, spacing: Theme.Spacing.xxs) {
                Text(title).font(.body)
                Text(detail).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }.padding(Theme.Spacing.m)
    }
}

private struct OnboardingCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.panel, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

struct EnableExtensionStep: View {
    @State private var enabled = FIFinderSyncController.isExtensionEnabled
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: Theme.Spacing.s)
            IconTile(symbol: "puzzlepiece.extension.fill", tint: .green, size: 56, style: .solid)
            Text("启用 Finder 扩展").font(.title2.weight(.bold))
            Text("需要在系统设置中启用 FinderRight 扩展").font(.callout).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: Theme.Spacing.l) {
                instruction(1, "点击「打开扩展设置」")
                instruction(2, "在打开的列表中勾选 FinderRightSync")
                instruction(3, "回到这里，状态会自动更新")
            }
            .frame(maxWidth: .infinity, alignment: .leading).padding(Theme.Spacing.l).modifier(OnboardingCard())
            Button("打开扩展设置") { FIFinderSyncController.showExtensionManagementInterface() }
                .buttonStyle(.bordered).controlSize(.large)
            StatusBadge(kind: enabled ? .success : .warning, text: enabled ? "已启用" : "未启用")
                .accessibilityLabel(enabled ? "Finder 扩展，已启用" : "Finder 扩展，未启用")
            ExtensionSetupHint().font(.subheadline)
            Spacer(minLength: Theme.Spacing.s)
        }
        .padding(.horizontal, 64).padding(.vertical, Theme.Spacing.m)
        .onAppear { enabled = FIFinderSyncController.isExtensionEnabled }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            enabled = FIFinderSyncController.isExtensionEnabled
        }
    }
    private func instruction(_ number: Int, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: Theme.Spacing.m) {
            Text(verbatim: String(number)).font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 20, height: 20).background(Color.accentColor, in: Circle()).accessibilityHidden(true)
            Text(title).font(.body)
        }
    }
}

struct CompletionStep: View {
    @State private var showCheckmark = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        VStack(spacing: Theme.Spacing.l) {
            Spacer(minLength: Theme.Spacing.s)
            Image(systemName: "checkmark.circle.fill").resizable().scaledToFit().frame(width: 56, height: 56)
                .foregroundStyle(.green).scaleEffect(showCheckmark || reduceMotion ? 1 : 0.5)
                .opacity(showCheckmark || reduceMotion ? 1 : 0)
                .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                .accessibilityHidden(true)
            Text("一切就绪").font(.title2.weight(.bold))
            VStack(spacing: Theme.Spacing.s) {
                Text("右键菜单预览").font(.subheadline).foregroundStyle(.secondary)
                VStack(spacing: 0) {
                    ForEach(MenuGroup.allCases, id: \.self) { group in
                        HStack {
                            Text(group.titleKey).font(.body)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption)
                                .foregroundStyle(group == .files ? Color.white : Color.secondary).accessibilityHidden(true)
                        }
                        .foregroundStyle(group == .files ? Color.white : Color.primary)
                        .padding(.horizontal, Theme.Spacing.s).frame(height: 22)
                        .background(group == .files ? Color.accentColor : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                .padding(5).frame(width: 220)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color(nsColor: .separatorColor), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.s) {
                Label("云盘目录请使用右键 → 服务", systemImage: "icloud")
                Label("可在设置中调整菜单项和快捷键", systemImage: "slider.horizontal.3")
            }.font(.subheadline).foregroundStyle(.secondary)
            Spacer(minLength: Theme.Spacing.s)
        }.padding(Theme.Spacing.xl).onAppear { showCheckmark = true }
    }
}

#Preview("Onboarding Light") { OnboardingView().preferredColorScheme(.light) }
#Preview("Onboarding Dark") { OnboardingView().preferredColorScheme(.dark) }
