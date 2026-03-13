import WatchKit

/// ハプティクスフィードバックマネージャー
struct HapticsManager {
    
    /// rep成功時の振動フィードバック
    static func playRepSuccess() {
        WKInterfaceDevice.current().play(.click)
    }
    
    /// 目標回数達成時の振動フィードバック
    static func playGoalReached() {
        WKInterfaceDevice.current().play(.success)
    }
    
    /// セット終了時の振動フィードバック
    static func playSetComplete() {
        WKInterfaceDevice.current().play(.notification)
    }
}
