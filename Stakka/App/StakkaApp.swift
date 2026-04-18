import SwiftUI

@main
struct StakkaApp: App {
    private let container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView(container: container)
        }
    }
}
