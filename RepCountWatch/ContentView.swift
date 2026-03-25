#if os(watchOS)
//
//  ContentView.swift
//  RepCountWatch
//
//  Created by 杉江孝士 on 2026-03-13.
//

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
