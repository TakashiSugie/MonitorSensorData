//
//  RepDetector.swift
//  BenchSense_r1 Watch App
//
//  主動軸自動追従・対称ピーク検出によるベンチプレスrep検出
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
    private(set) var lastRepMeanVelocity: Double = 0.0

    /// rep検出時のコールバック
    var onRepDetected: (() -> Void)?

    // MARK: - Thresholds

    // 80kgなどの高重量（低速動作）を拾うため、閾値を大きく引き下げます
    private let peakThreshold: Double = 0.12

    // MARK: - Filtering & Dynamic Axis

    /// ローパスフィルタ係数
    private let filterAlpha: Double = 0.2

    private var filteredAccX: Double = 0.0
    private(set) var filteredAccY: Double = 0.0
    private var filteredAccZ: Double = 0.0

    /// 各軸の動きの大きさ（エネルギー）を追跡
    private var energyX: Double = 0.0
    private var energyY: Double = 0.0
    private var energyZ: Double = 0.0

    // MARK: - State tracking

    /// 次に期待するピークの方向（true: 正のピーク, false: 負のピーク, nil: 未定）
    private var isLookingForPositivePeak: Bool? = nil

    /// 1回の動き（切り返し）をカウント
    private var halfRepCount: Int = 0

    /// クールダウン（二重カウント防止）
    private let cooldownInterval: TimeInterval = 0.45
    private var lastStateChange: Date = .distantPast

    // MARK: - Public Methods

    func processAcceleration(accX: Double, accY: Double, accZ: Double) {
        // 1. 各軸のローパスフィルタリング
        filteredAccX = filterAlpha * accX + (1.0 - filterAlpha) * filteredAccX
        filteredAccY = filterAlpha * accY + (1.0 - filterAlpha) * filteredAccY
        filteredAccZ = filterAlpha * accZ + (1.0 - filterAlpha) * filteredAccZ

        // 2. 各軸のエネルギーを計算（長めの移動平均）
        energyX = 0.95 * energyX + 0.05 * abs(filteredAccX)
        energyY = 0.95 * energyY + 0.05 * abs(filteredAccY)
        energyZ = 0.95 * energyZ + 0.05 * abs(filteredAccZ)

        // 3. 最もエネルギーが大きい軸（主動軸）を自動選択（符号付き）
        let activeAcc: Double
        if energyX >= energyY && energyX >= energyZ {
            activeAcc = filteredAccX
        } else if energyY >= energyX && energyY >= energyZ {
            activeAcc = filteredAccY
        } else {
            activeAcc = filteredAccZ
        }

        // 4. 対称ピーク検出アルゴリズム
        updateStateMachine(activeAcc: activeAcc)
    }

    func reset() {
        repCount = 0
        currentPhase = .idle

        filteredAccX = 0.0; filteredAccY = 0.0; filteredAccZ = 0.0
        energyX = 0.0; energyY = 0.0; energyZ = 0.0

        halfRepCount = 0
        isLookingForPositivePeak = nil
        lastStateChange = .distantPast
    }

    func addRep() {
        repCount += 1
    }

    func removeRep() {
        repCount = max(0, repCount - 1)
    }

    // MARK: - Private Methods

    private func updateStateMachine(activeAcc: Double) {
        let now = Date()

        if isLookingForPositivePeak == nil {
            // 最初のアクション: 正でも負でも、閾値を超えたら動作開始とみなす
            if activeAcc < -peakThreshold {
                isLookingForPositivePeak = true // 次は正のピーク（反対への切り返し）を待つ
                lastStateChange = now
                currentPhase = .descending
            } else if activeAcc > peakThreshold {
                isLookingForPositivePeak = false // 次は負のピーク（反対への切り返し）を待つ
                lastStateChange = now
                currentPhase = .descending
            }
        }
        else if isLookingForPositivePeak == true {
            // 正のピーク（ボトム等での切り返し）を待機
            if activeAcc > peakThreshold {
                if now.timeIntervalSince(lastStateChange) > cooldownInterval {
                    isLookingForPositivePeak = false
                    lastStateChange = now

                    halfRepCount += 1
                    updateRepCountPhase()
                }
            }
        }
        else if isLookingForPositivePeak == false {
            // 負のピーク（トップ等での切り返し）を待機
            if activeAcc < -peakThreshold {
                if now.timeIntervalSince(lastStateChange) > cooldownInterval {
                    isLookingForPositivePeak = true
                    lastStateChange = now

                    halfRepCount += 1
                    updateRepCountPhase()
                }
            }
        }
    }

    private func updateRepCountPhase() {
        // ピークの往復（2回の切り返し）で1Repとカウント
        if halfRepCount % 2 == 0 {
            repCount += 1
            currentPhase = .lockout
            onRepDetected?()
        } else {
            currentPhase = .bottom
        }
    }
}
