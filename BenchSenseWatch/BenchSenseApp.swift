#if os(watchOS)
import SwiftUI

/// BenchSense watchOSアプリのエントリポイント
@main
struct BenchSenseApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
#endif
