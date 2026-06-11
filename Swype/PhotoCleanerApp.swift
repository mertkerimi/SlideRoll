import SwiftUI
import Photos
import GoogleMobileAds

@main
struct PhotoCleanerApp: App {
    @State private var vm = PhotoLibraryViewModel()
    @State private var lm = LanguageManager()
    @State private var adManager = AdManager()

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .environment(lm)
                .environment(adManager)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                    }
                }
        }
    }
}
