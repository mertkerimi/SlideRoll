import SwiftUI
import Photos

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm
    @Environment(LanguageManager.self) var lm

    var body: some View {
        switch vm.authStatus {
        case .authorized, .limited:
            MonthListView()
        case .denied, .restricted:
            PermissionView(onRequest: {})
                .environment(lm)
                .overlay(alignment: .top) {
                    Text(lm.s.allowInSettings)
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding()
                }
        default:
            PermissionView {
                await vm.requestPermission()
            }
            .environment(lm)
        }
    }
}
