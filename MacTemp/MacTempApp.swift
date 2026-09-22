import SwiftUI

@main
struct MacTempApp: App {
    @StateObject private var monitor = TemperatureMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView(monitor: monitor)
                .frame(minWidth: 880, minHeight: 650)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh temperatures") {
                    monitor.refresh()
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
        }
    }
}
