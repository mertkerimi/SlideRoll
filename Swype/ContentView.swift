import SwiftUI
import Photos

struct ContentView: View {
    @Environment(PhotoLibraryViewModel.self) var vm

    var body: some View {
        switch vm.authStatus {
        case .authorized, .limited:
            MonthListView()
        case .denied, .restricted:
            PermissionView(onRequest: {})
                .overlay(alignment: .top) {
                    Text("Fotoğraflara erişim reddedildi. Ayarlardan izin verin.")
                        .multilineTextAlignment(.center)
                        .font(.callout)
                        .foregroundColor(.secondary)
                        .padding()
                }
        default:
            PermissionView {
                await vm.requestPermission()
            }
        }
    }
}
