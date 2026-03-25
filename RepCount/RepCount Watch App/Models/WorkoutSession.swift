//
//  WorkoutSession.swift
//  RepCount Watch App
//

import Foundation

struct WorkoutSession: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date
    var exerciseType: String
    var repCount: Int
    var duration: TimeInterval
    var weight: Int?
    var velocities: [Double] = [] // 格Repごとの速度 (VBT) を記録
    
    // MARK: - Computed Properties
    
    /// 推定MAX重量 (1RM) - Epley公式: W * (1 + 0.0333 * R)
    var estimated1RM: Int? {
        guard let w = weight, repCount > 0 else { return nil }
        let rm = Double(w) * (1.0 + 0.0333 * Double(repCount))
        return Int(round(rm))
    }
    
    /// 当セッションの平均VBT
    var averageVelocity: Double {
        guard !velocities.isEmpty else { return 0.0 }
        let sum = velocities.reduce(0, +)
        return sum / Double(velocities.count)
    }
    
    /// 当セッションの最大VBT
    var maxVelocity: Double {
        return velocities.max() ?? 0.0
    }
}
