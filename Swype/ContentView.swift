import SwiftUI
import Photos

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView { showSplash = false }
                    .transition(.opacity)
                    .zIndex(1)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showSplash)
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
