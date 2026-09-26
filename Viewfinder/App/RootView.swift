import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            if model.hasOnboarded {
                MainTabView()
                    .transition(.opacity)
            } else {
                OnboardingView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: model.hasOnboarded)
    }
}

/// 탭 3개: 탐색 → 롤 → 필드 (발견 → 계획 → 현장)
/// 시스템 탭바 대신 직접 그려서 Frame 뷰에서 자연스럽게 숨길 수 있게 합니다.
struct MainTabView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var model = model
        ZStack {
            ExploreView()
                .opacity(model.selectedTab == .explore ? 1 : 0)
                .allowsHitTesting(model.selectedTab == .explore)
                .accessibilityHidden(model.selectedTab != .explore)
            RollsView()
                .opacity(model.selectedTab == .rolls ? 1 : 0)
                .allowsHitTesting(model.selectedTab == .rolls)
                .accessibilityHidden(model.selectedTab != .rolls)
            if model.selectedTab == .field {
                // 카메라·나침반은 필드 탭이 보일 때만 켭니다.
                FieldView()
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if !(model.selectedTab == .explore && model.chromeHidden) {
                VFTabBar(selection: $model.selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // 필드 탭의 야간 적색 모드: 화면 전체를 붉은빛으로
        .colorMultiply(model.selectedTab == .field && model.nightRedMode ? Color(red: 1, green: 0.16, blue: 0.12) : Color.white)
        .animation(.easeInOut(duration: 0.22), value: model.chromeHidden)
        .animation(.easeInOut(duration: 0.18), value: model.selectedTab)
    }
}

struct VFTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let isOn = selection == tab
                Button {
                    guard selection != tab else { return }
                    Haptics.tick()
                    selection = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: isOn ? .semibold : .regular))
                            .frame(height: 22)
                        Text(tab.title)
                            .font(VF.Typeface.label(11))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)
                    .padding(.bottom, 4)
                    .foregroundStyle(isOn ? VF.Palette.amber : VF.Palette.textSecondary)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(VF.Palette.amber)
                            .frame(width: isOn ? 18 : 0, height: 2)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tab.title)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.horizontal, 12)
        .background {
            VF.Palette.background
                .opacity(0.94)
                .overlay(alignment: .top) {
                    Rectangle().fill(VF.Palette.hairline).frame(height: VF.Metric.hairline)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
