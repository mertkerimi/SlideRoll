import SwiftUI
import Photos
import AppTrackingTransparency

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm
    @Environment(NotificationManager.self) var notif

    @State private var showSplash = true
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
                    .zIndex(2)
            } else if !hasSeenOnboarding {
                OnboardingView { hasSeenOnboarding = true }
                    .environment(lm)
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasSeenOnboarding)
    }

    @ViewBuilder
    private var mainContent: some View {
        switch vm.authStatus {
        case .authorized, .limited:
            RootView()
        case .denied, .restricted:
            PermissionView(onRequest: {})
                .environment(lm)
        default:
            PermissionView {
                await vm.requestPermission()
                if vm.authStatus == .authorized || vm.authStatus == .limited {
                    await requestPostPhotoPermissions()
                }
            }
            .environment(lm)
        }
    }

    private func requestPostPhotoPermissions() async {
        try? await Task.sleep(nanoseconds: 800_000_000)
        if #available(iOS 14.5, *) {
            await ATTrackingManager.requestTrackingAuthorization()
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let granted = await notif.requestPermission()
        if granted {
            notif.enabled = true
            notif.reschedule(language: lm.selected)
        }
    }
}
