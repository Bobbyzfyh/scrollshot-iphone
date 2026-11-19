import SwiftUI

@main
struct ScrollshotApp: App {
    @StateObject private var capture = CaptureController()
    var body: some Scene {
        WindowGroup {
            HomeView(model: capture)
                .preferredColorScheme(.light)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in capture.resignActive() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in capture.enteredBackground() }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in capture.enteringForeground() }
        }
    }
}
