#if os(watchOS)
import WatchKit
#endif

/// ハプティクスフィードバックマネージャー
struct HapticsManager {
    
    /// rep成功時の振動フィードバック
    static func playRepSuccess() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.click)
        #endif
    }
    
    /// 目標回数達成時の振動フィードバック
    static func playGoalReached() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.success)
        #endif
    }
    
    /// セット終了時の振動フィードバック
    static func playSetComplete() {
        #if os(watchOS)
        WKInterfaceDevice.current().play(.notification)
        #endif
    }
}
