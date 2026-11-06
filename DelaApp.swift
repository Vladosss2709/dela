import SwiftUI
import UserNotifications

@main
struct DelaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var tasks = TaskStore()
    @StateObject private var expenses = ExpenseStore()
    @StateObject private var wishes = WishStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tasks)
                .environmentObject(expenses)
                .environmentObject(wishes)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Показывать уведомление, даже если приложение открыто
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
