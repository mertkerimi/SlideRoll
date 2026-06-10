import SwiftUI
import Photos

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

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
            }
            .environment(lm)
        }
    }
}
