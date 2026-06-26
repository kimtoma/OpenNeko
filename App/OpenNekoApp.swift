import SwiftUI
import OpenNekoKit

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
    private var catWindow: CatWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let cat = CatWindow()
        catWindow = cat

        let spritesURL = Bundle.main.resourceURL!.appendingPathComponent("sprites")
        let manager = SkinManager(bundledRoot: spritesURL, externalRoot: nil)
        cat.showCat(skin: manager.loadDefault())

        menuBar = MenuBarController(
            onToggleCat: { [weak cat] in cat?.toggle() },
            onQuit: { NSApp.terminate(nil) }
        )
    }
}
