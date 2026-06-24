import SwiftUI
import Photos
import GoogleMobileAds
import AppTrackingTransparency

@main
struct SlideRollApp: App {
    @State private var vm    = PhotoLibraryViewModel()
    @State private var lm    = LanguageManager()
    @State private var adMan = AdManager()
    @State private var notif = NotificationManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MobileAds.shared.start(completionHandler: nil)
    }

    private func requestTrackingIfNeeded() {
        guard #available(iOS 14.5, *) else { return }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            await ATTrackingManager.requestTrackingAuthorization()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(vm)
                .environment(lm)
                .environment(adMan)
                .environment(notif)
                .preferredColorScheme(lm.appearanceMode.colorScheme)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                        requestTrackingIfNeeded()
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
