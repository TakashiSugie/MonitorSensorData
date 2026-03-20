//
//  HapticManager.swift
//  BenchSense_r1 Watch App
//
//  WatchKit ハプティクスフィードバック
//

import WatchKit

struct HapticManager {
    
    /// rep成功時の振動（クリック）
    static func playRepSuccess() {
        WKInterfaceDevice.current().play(.click)
    }
    
    /// 目標回数到達時の振動（サクセス）
    static func playGoalReached() {
        WKInterfaceDevice.current().play(.success)
    }
    
    /// セット終了時の振動（通知）
    static func playSetComplete() {
        WKInterfaceDevice.current().play(.notification)
    }
}
