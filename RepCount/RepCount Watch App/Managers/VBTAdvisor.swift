//
//  VBTAdvisor.swift
//  BenchCoach Watch App
//
//  VBTを活用したパーソナライズ（オートレギュレーション）機能
//  第1Repの速度を過去データと比較し、コンディションと対策を提案する
//

import Foundation

enum PhysicalCondition: String {
    case excellent = "絶好調"
    case normal = "通常"
    case fatigued = "疲労気味"
    case uncalculated = "データ不足"
    
    var advice: String {
        switch self {
        case .excellent:
            return "+2.5kg 追加、または予定より多めの回数を推奨"
        case .normal:
            return "予定通りの重量と回数で実施"
        case .fatigued:
            return "-2.5kg 減らすか、回数を抑えることを推奨"
        case .uncalculated:
            return "データが蓄積されるとアドバイスが表示されます"
        }
    }
}

struct AdviceResult {
    let condition: PhysicalCondition
    let message: String
}

class VBTAdvisor {
    
    /// 当日のセッションデータと履歴データからアドバイスを生成する
    /// - Parameters:
    ///   - currentSession: 現在終わったばかりのワークアウトセッション
    ///   - allHistory: 過去のすべてのワークアウトセッション履歴
    /// - Returns: アドバイス結果
    static func evaluateCondition(currentSession: WorkoutSession, allHistory: [WorkoutSession]) -> AdviceResult {
        
        // 1Rep以上のデータがあるか、重量が設定されているか
        guard let currentWeight = currentSession.weight,
              let firstRepVelocity = currentSession.velocities.first,
              currentSession.velocities.count > 0 else {
            return AdviceResult(condition: .uncalculated, message: PhysicalCondition.uncalculated.advice)
        }
        
        // 過去の同重量のセッションを抽出（今回のセッション自身は除く）
        let pastSessions = allHistory.filter { session in
            session.weight == currentWeight && session.id != currentSession.id && session.velocities.count > 0
        }
        
        // 履歴がない場合は比較できないためデータ不足とする
        guard !pastSessions.isEmpty else {
            return AdviceResult(condition: .uncalculated, message: PhysicalCondition.uncalculated.advice)
        }
        
        // 過去の同重量における「第1Rep目」の平均速度を計算
        let pastFirstRepVelocities = pastSessions.compactMap { $0.velocities.first }
        let historicalAverage = pastFirstRepVelocities.reduce(0, +) / Double(pastFirstRepVelocities.count)
        
        // 比較（±5%を基準とする）
        // (今日の第1Rep速度 - 過去平均) / 過去平均
        let differenceRatio = (firstRepVelocity - historicalAverage) / historicalAverage
        
        let condition: PhysicalCondition
        if differenceRatio > 0.05 {
            condition = .excellent
        } else if differenceRatio < -0.05 {
            condition = .fatigued
        } else {
            condition = .normal
        }
        
        // 追加のメッセージ構成
        let diffPercent = Int(round(differenceRatio * 100))
        let sign = diffPercent >= 0 ? "+" : ""
        let detailMessage = "過去の第1Rep平均(\(String(format: "%.2f", historicalAverage)) m/s) より \(sign)\(diffPercent)%\n\n\(condition.advice)"
        
        return AdviceResult(condition: condition, message: detailMessage)
    }
}
