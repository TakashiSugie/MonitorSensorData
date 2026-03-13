#if os(watchOS)
import SwiftUI

/// BenchSense watchOSアプリのエントリポイント
@main
struct BenchSenseWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
#endif
