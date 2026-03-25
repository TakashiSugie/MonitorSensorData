#if os(watchOS)
import SwiftUI

/// RepCount watchOSアプリのエントリポイント
@main
struct RepCountApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
    }
}
#endif
