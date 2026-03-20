//
//  BenchSense_r1App.swift
//  BenchSense_r1 Watch App
//

import SwiftUI

@main
struct BenchSense_r1_Watch_AppApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
        }
    }
}
