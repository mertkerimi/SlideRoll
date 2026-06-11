import SwiftUI
import Photos
import GoogleMobileAds

@main
struct PhotoCleanerApp: App {
    @State private var vm    = PhotoLibraryViewModel()
    @State private var lm    = LanguageManager()
    @State private var adMan = AdManager()
    @State private var notif = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .environment(lm)
                .environment(adMan)
                .environment(notif)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                    }
                    await notif.refreshStatus()
                    notif.reschedule(language: lm.selected)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task {
                        await notif.refreshStatus()
                        notif.reschedule(language: lm.selected)
                    }
                }
        }
    }
}
