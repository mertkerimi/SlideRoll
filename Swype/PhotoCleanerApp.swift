import SwiftUI
import Photos

@main
struct PhotoCleanerApp: App {
    @State private var vm = PhotoLibraryViewModel()
    @State private var lm = LanguageManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .environment(lm)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                    }
                }
        }
    }
}
