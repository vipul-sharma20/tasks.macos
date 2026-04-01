import SwiftUI

@main
struct TaskBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra("Tasks", systemImage: "checklist") {
            TaskListView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_: Notification) {
        // No dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)
    }
}
