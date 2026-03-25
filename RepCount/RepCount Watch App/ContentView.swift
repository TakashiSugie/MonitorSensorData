//
//  ContentView.swift
//  BenchCoach Watch App
//
//  画面遷移の管理
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        Group {
            switch workoutManager.appState {
            case .home:
                HomeView()
            case .workout:
                WorkoutView()
            case .result:
                ResultView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: workoutManager.appState)
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutManager())
}
