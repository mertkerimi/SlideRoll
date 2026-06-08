import SwiftUI
import Photos

@main
struct PhotoCleanerApp: App {
    @State private var vm = PhotoLibraryViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                    }
                }
        }
    }
}
