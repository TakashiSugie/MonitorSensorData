//
//  WorkoutSession.swift
//  BenchSense_r1 Watch App
//

import Foundation

struct WorkoutSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var exerciseType: String
    var repCount: Int
    var duration: TimeInterval
    var weight: Int?
}
