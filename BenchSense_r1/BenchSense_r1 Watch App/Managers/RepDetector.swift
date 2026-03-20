//
//  RepDetector.swift
//  BenchSense_r1 Watch App
//
//  状態マシンによるベンチプレスrep検出
//

import Foundation

/// ベンチプレスの動作フェーズ
enum RepPhase: String {
    case idle        // 待機中
    case descending  // 下降中（バーを下ろしている）
    case bottom      // 最下点
    case ascending   // 上昇中（バーを押し上げている）
    case lockout     // ロックアウト（腕を伸ばしきった）
}

class RepDetector {
    
    // MARK: - Properties
    
    private(set) var repCount: Int = 0
    private(set) var currentPhase: RepPhase = .idle
    
    /// rep検出時のコールバック
    var onRepDetected: (() -> Void)?
    
    // MARK: - Thresholds
    
    /// 下降検出の加速度閾値（Y軸, 負方向）
    private let descendThreshold: Double = -0.3
    
    /// 上昇検出の加速度閾値（Y軸, 正方向）
    private let ascendThreshold: Double = 0.3
    
    /// 最下点検出の速度低下閾値
    private let bottomThreshold: Double = 0.15
    
    /// ロックアウト（安定状態）の閾値
    private let lockoutThreshold: Double = 0.15
    
    // MARK: - Filtering
    
    /// ローパスフィルタの係数（0〜1, 小さいほど平滑化）
    private let filterAlpha: Double = 0.2
    
    /// フィルタ済み加速度
    private(set) var filteredAccY: Double = 0.0
    private var filteredAccMagnitude: Double = 0.0
    
    // MARK: - Cooldown
    
    /// 二重カウント防止のクールダウン（800ms）
    private let cooldownInterval: TimeInterval = 0.8
    private var lastRepTime: Date = .distantPast
    
    // MARK: - State tracking
    
    /// 下降時の最大加速度（負の値の絶対値）
    private var descentPeakAccY: Double = 0.0
    
    /// 上昇時の最大加速度
    private var ascentPeakAccY: Double = 0.0
    
    // MARK: - Public Methods
    
    /// 加速度データを処理してrep検出を行う
    /// - Parameters:
    ///   - accX: X軸の加速度
    ///   - accY: Y軸の加速度（重力方向）
    ///   - accZ: Z軸の加速度
    func processAcceleration(accX: Double, accY: Double, accZ: Double) {
        // ローパスフィルタ適用
        filteredAccY = filterAlpha * accY + (1.0 - filterAlpha) * filteredAccY
        let magnitude = sqrt(accX * accX + accY * accY + accZ * accZ)
        filteredAccMagnitude = filterAlpha * magnitude + (1.0 - filterAlpha) * filteredAccMagnitude
        
        // 状態マシンによる判定
        updateStateMachine()
    }
    
    /// rep カウントをリセット
    func reset() {
        repCount = 0
        currentPhase = .idle
        filteredAccY = 0.0
        filteredAccMagnitude = 0.0
        descentPeakAccY = 0.0
        ascentPeakAccY = 0.0
        lastRepTime = .distantPast
    }
    
    /// 手動でrepを追加
    func addRep() {
        repCount += 1
    }
    
    /// 手動でrepを削除（0未満にはならない）
    func removeRep() {
        repCount = max(0, repCount - 1)
    }
    
    // MARK: - Private Methods
    
    private func updateStateMachine() {
        switch currentPhase {
        case .idle:
            // 下降動作の開始を検出
            if filteredAccY < descendThreshold {
                currentPhase = .descending
                descentPeakAccY = filteredAccY
            }
            
        case .descending:
            // より大きな下降加速度を記録
            if filteredAccY < descentPeakAccY {
                descentPeakAccY = filteredAccY
            }
            
            // 速度低下 → 最下点到達
            if abs(filteredAccY) < bottomThreshold && descentPeakAccY < descendThreshold {
                currentPhase = .bottom
            }
            
            // 下降が中断された場合はIDLEに戻る
            if filteredAccY > ascendThreshold {
                currentPhase = .idle
                descentPeakAccY = 0.0
            }
            
        case .bottom:
            // 上昇動作の開始を検出
            if filteredAccY > ascendThreshold {
                currentPhase = .ascending
                ascentPeakAccY = filteredAccY
            }
            
            // 最下点でさらに下降する場合は descending に戻す
            if filteredAccY < descendThreshold {
                currentPhase = .descending
            }
            
        case .ascending:
            // より大きな上昇加速度を記録
            if filteredAccY > ascentPeakAccY {
                ascentPeakAccY = filteredAccY
            }
            
            // 安定状態 → ロックアウト
            if abs(filteredAccY) < lockoutThreshold && ascentPeakAccY > ascendThreshold {
                currentPhase = .lockout
            }
            
        case .lockout:
            // クールダウンチェック後にrepをカウント
            let now = Date()
            if now.timeIntervalSince(lastRepTime) >= cooldownInterval {
                repCount += 1
                lastRepTime = now
                currentPhase = .idle
                descentPeakAccY = 0.0
                ascentPeakAccY = 0.0
                onRepDetected?()
            } else {
                currentPhase = .idle
                descentPeakAccY = 0.0
                ascentPeakAccY = 0.0
            }
        }
    }
}
