import SwiftUI
import Photos

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

    var body: some View {
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
