import SwiftUI

enum AppTab {
    case home, stats, settings
}

struct RootView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

    @State private var selectedTab: AppTab = .home
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @State private var showTour = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    MonthListView()
                        .onAppear {
                            if !hasSeenAppTour {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showTour = true
                                }
                            }
                        }
                case .stats:
                    NavigationStack {
                        StatsView()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    Text(lm.s.statTitle)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                    }
                case .settings:
                    NavigationStack {
                        SettingsView()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    Text(lm.s.settings)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
                                }
                            }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(lm.themeVersion)

            floatingTabBar
                .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .bottom)
        .overlayPreferenceValue(TourAnchorKey.self) { anchors in
            if showTour {
                GeometryReader { proxy in
                    AppTourOverlay(
                        anchors: anchors,
                        proxy: proxy,
                        onFinish: {
                            withAnimation(.easeInOut(duration: 0.3)) { showTour = false }
                            hasSeenAppTour = true
                        }
                    )
                    .environment(lm)
                }
                .ignoresSafeArea()
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showTour)
    }

    // MARK: - Floating Tab Bar

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "photo.stack.fill", label: lm.s.tabHome, tab: .home)
            tabItem(icon: "chart.bar.fill",   label: lm.s.tabStats, tab: .stats)
            tabItem(icon: "gearshape.fill",   label: lm.s.tabSettings, tab: .settings)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        )
        .tourAnchor(.tabBar)
        .padding(.horizontal, 48)
    }

    private func tabItem(icon: String, label: String, tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 44, height: 30)
                            .transition(.scale.combined(with: .opacity))
                    }
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                        .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
                }
                .frame(width: 44, height: 30)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
