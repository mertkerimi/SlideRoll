import SwiftUI

enum AppTab {
    case home, albums, stats, settings
}

struct RootView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(NotificationManager.self) var notif
    @Environment(SubscriptionManager.self) var subManager

    @State private var selectedTab: AppTab = .home
    @AppStorage("hasSeenAppTour") private var hasSeenAppTour = false
    @State private var showTour = false
    @State private var tabBarHidden = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    MonthListView(selectedTab: $selectedTab)
                        .onAppear {
                            if !hasSeenAppTour {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                    showTour = true
                                }
                            }
                        }
                case .albums:
                    NavigationStack {
                        AlbumsView()
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .principal) {
                                    Text(lm.s.tabAlbums)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(Theme.textPrimary)
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
                        SettingsView().environment(notif).environment(vm)
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

            if !tabBarHidden {
                floatingTabBar
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideTabBar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { tabBarHidden = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showTabBar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { tabBarHidden = false }
        }
        .ignoresSafeArea(edges: .bottom)
        .onOpenURL { url in
            guard url.scheme == "slideroll" else { return }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { selectedTab = .home }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if url.host == "year", let year = url.pathComponents.dropFirst().first {
                    NotificationCenter.default.post(name: .widgetOpenYear, object: year)
                } else if url.host == "shuffle" {
                    NotificationCenter.default.post(name: .widgetOpenShuffle, object: nil)
                }
            }
        }
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

    @Namespace private var tabNS

    private var floatingTabBar: some View {
        HStack(spacing: 0) {
            tabItem(icon: "photo.stack.fill",     label: lm.s.tabHome,     tab: .home)
            tabItem(icon: "rectangle.stack.fill", label: lm.s.tabAlbums,   tab: .albums,   showCrown: true)
            tabItem(icon: "chart.bar.fill",       label: lm.s.tabStats,    tab: .stats,    showCrown: true)
            tabItem(icon: "gearshape.fill",       label: lm.s.tabSettings, tab: .settings)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .white.opacity(0.08)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.18), radius: 20, y: 8)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        }
        .tourAnchor(.tabBar)
        .padding(.horizontal, 40)
    }

    private func tabItem(icon: String, label: String, tab: AppTab, showCrown: Bool = false) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            withAnimation(.smooth(duration: 0.35)) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(Theme.accent)
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "tabPill", in: tabNS)
                            .shadow(color: Theme.accent.opacity(0.45), radius: 10, y: 4)
                    }
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? .white : Theme.textTertiary)
                        .scaleEffect(isSelected ? 1.05 : 1.0)
                        .animation(.smooth(duration: 0.3), value: isSelected)

                    if showCrown {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(subManager.isPremium ? .yellow : Theme.textTertiary)
                            .offset(x: 18, y: -10)
                    }
                }
                .frame(width: 52, height: 32)

                Text(label)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Theme.accent : Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
