#if os(watchOS)
import SwiftUI

/// RepCount watchOSアプリのエントリポイント
@main
struct RepCountWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
#endif
