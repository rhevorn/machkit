import SwiftUI

@main
struct SiftApp: App {
    var body: some Scene {
        WindowGroup("Sift") {
            ContentView()
                .frame(minWidth: 620, minHeight: 720)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 720, height: 820)
    }
}
