#if os(watchOS)
import SwiftUI

/// メインコンテンツビュー - HomeViewへ遷移
struct ContentView: View {
    var body: some View {
        HomeView()
    }
}

#Preview {
    ContentView()
}
#endif
