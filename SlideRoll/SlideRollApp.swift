import SwiftUI
import Photos
import UserNotifications
import GoogleMobileAds
import AppTrackingTransparency

// Shows notifications as banners even when the app is in the foreground.
final class SlideRollNotifDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct SlideRollApp: App {
    private let notifDelegate = SlideRollNotifDelegate()
    @State private var vm      = PhotoLibraryViewModel()
    @State private var lm      = LanguageManager()
    @State private var adMan   = AdManager()
    @State private var notif   = NotificationManager()
    @State private var subMan  = SubscriptionManager()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MobileAds.shared.start(completionHandler: nil)
        UNUserNotificationCenter.current().delegate = notifDelegate
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
                .environment(subMan)
                .preferredColorScheme(lm.appearanceMode.colorScheme)
                .animation(.smooth(duration: 0.5), value: lm.appearanceMode)
                .task {
                    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
                    if status == .authorized || status == .limited {
                        await vm.loadPhotos()
                        requestTrackingIfNeeded()
                    }
                    await subMan.loadProducts()
                    adMan.isPremium = subMan.isPremium
                    await notif.refreshStatus()
                    // Uygulama açıkken bekleyen bildirimleri iptal et
                    notif.cancelAll()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // Kullanıcı uygulamaya döndü — bekleyen bildirimleri iptal et
                        Task { await notif.refreshStatus() }
                        notif.cancelAll()
                    case .background:
                        // Kullanıcı uygulamayı kapattı — 5 ve 10 saat sonrası için planla
                        notif.reschedule(language: lm.selected)
                    default:
                        break
                    }
                }
        }
    }
}
