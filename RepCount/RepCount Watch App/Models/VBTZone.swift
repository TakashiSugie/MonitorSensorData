//
//  VBTZone.swift
//  RepCount Watch App
//
//  VBTトレーニングの目的別ターゲットゾーン定義
//

import Foundation

enum VBTZone: String, CaseIterable, Identifiable {
    case maxStrength = "最大筋力"
    case hypertrophy = "筋肥大"
    case power = "パワー向上"
    
    var id: String { self.rawValue }
    
    var range: ClosedRange<Double> {
        switch self {
        case .maxStrength:
            return 0.15...0.35
        case .hypertrophy:
            return 0.35...0.60
        case .power:
            return 0.75...1.00
        }
    }
    
    var description: String {
        switch self {
        case .maxStrength:
            return "0.15 - 0.35 m/s"
        case .hypertrophy:
            return "0.35 - 0.60 m/s"
        case .power:
            return "0.75 - 1.00 m/s"
        }
    }
}
