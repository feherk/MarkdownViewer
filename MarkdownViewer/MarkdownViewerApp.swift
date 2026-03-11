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
                Button("Markdown Viewer Help") {
                    // Help window
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var initializedWindows = Set<ObjectIdentifier>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set initial size and position only for newly created windows
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { [weak self] notification in
            guard let self, let window = notification.object as? NSWindow else { return }
            let windowID = ObjectIdentifier(window)
            guard !self.initializedWindows.contains(windowID) else { return }
            self.initializedWindows.insert(windowID)

            let screenSize = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
            let windowWidth: CGFloat = min(1000, screenSize.width * 0.7)
            let windowHeight: CGFloat = min(750, screenSize.height * 0.8)
            window.setContentSize(NSSize(width: windowWidth, height: windowHeight))
            window.center()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Only quit if there was an open document (not when the Open panel closes)
        // Check with a small delay if there are still documents
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if NSDocumentController.shared.documents.isEmpty && NSApp.windows.filter({ $0.isVisible }).isEmpty {
                NSApp.terminate(nil)
            }
        }
        return false
    }
}
