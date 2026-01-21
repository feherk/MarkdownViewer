import SwiftUI

@main
struct MarkdownViewerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            CommandGroup(replacing: .help) {
                Button("Markdown Viewer Súgó") {
                    // Súgó ablak
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ablak méretezése és középre helyezése
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { notification in
            if let window = notification.object as? NSWindow {
                let screenSize = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
                let windowWidth: CGFloat = min(1000, screenSize.width * 0.7)
                let windowHeight: CGFloat = min(750, screenSize.height * 0.8)
                window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
                window.center()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Csak akkor lépjen ki, ha volt megnyitott dokumentum (nem az Open panel záródik)
        // Kis késleltetéssel ellenőrizzük, hogy van-e még dokumentum
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if NSDocumentController.shared.documents.isEmpty && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.terminate(nil)
            }
        }
        return false
    }
}
