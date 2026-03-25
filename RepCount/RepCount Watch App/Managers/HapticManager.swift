//
//  HapticManager.swift
//  RepCount Watch App
//
//  WatchKit ハプティクスフィードバック
//

import WatchKit

struct HapticManager {
    
    /// rep成功時の振動（サクセス：タッ・タッというより明確な2回の振動）
    static func playRepSuccess() {
        WKInterfaceDevice.current().play(.success)
    }
    
    /// 目標回数到達時の振動（サクセス）
    static func playGoalReached() {
        WKInterfaceDevice.current().play(.success)
    }
    
    /// セット終了時の振動（通知）
    static func playSetComplete() {
        WKInterfaceDevice.current().play(.notification)
    }
    
    /// ボタン操作時の軽いクリック感（触覚フィードバック）
    static func playClick() {
        WKInterfaceDevice.current().play(.click)
    }
}
