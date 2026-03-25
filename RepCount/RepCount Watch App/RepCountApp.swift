//
//  RepCountApp.swift
//  RepCount Watch App
//

import SwiftUI

@main
struct RepCount_Watch_AppApp: App {
    @StateObject private var workoutManager = WorkoutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutManager)
        }
    }
}
