import SwiftUI

@main
struct OpenNekoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement 앱: 보이는 Scene 없음. 메뉴바/창은 AppDelegate가 관리.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBar: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        menuBar = MenuBarController(
            onToggleCat: { /* Task 8에서 연결 */ },
            onQuit: { NSApp.terminate(nil) }
        )
    }
}
