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
    var peakThreshold: Double = 0.12

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

    // MARK: - Configuration

    /// アプリの設定から渡される着用腕（true: 左腕、false: 右腕）
    var isLeftArm: Bool = true

    // MARK: - State tracking

    /// 次に期待するピークの方向（true: 正のピーク, false: 負のピーク, nil: 未定）
    private var isLookingForPositivePeak: Bool? = nil

    /// 1回の動き（切り返し）をカウント
    private var halfRepCount: Int = 0

    /// クールダウン（二重カウント防止）
    private let cooldownInterval: TimeInterval = 0.45
    private var lastStateChange: Date = .distantPast

    // MARK: - Velocity Calculation (VBT)

    /// 上昇フェーズ（コンセントリック）中の速度積算用
    private var velocitySum: Double = 0.0
    private var ascendingSampleCount: Int = 0
    private var currentInstantaneousVelocity: Double = 0.0
    private let dt: Double = 1.0 / 50.0 // 50Hz
    private let g: Double = 9.80665

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

        // 5. 速度積分 (VBT)
        // currentPhase == .bottom は「ボトム通過後〜ロックアウトまで（上昇中）」を指す
        if currentPhase == .bottom {
            let ascendingAcc = isLeftArm ? -activeAcc : activeAcc
            
            // 加速度を積分して速度を求める
            // 押し上げ開始(v=0)からの累積
            // ※userAccelerationが正確であれば、上昇終了時にv=0付近に戻るはず
            currentInstantaneousVelocity += ascendingAcc * g * dt
            
            // 負の速度（下降やノイズ）は0でクリップして、押し上げ中のみを積算
            let v = max(0, currentInstantaneousVelocity)
            velocitySum += v
            ascendingSampleCount += 1
        }
    }

    func reset() {
        repCount = 0
        currentPhase = .idle

        filteredAccX = 0.0; filteredAccY = 0.0; filteredAccZ = 0.0
        energyX = 0.0; energyY = 0.0; energyZ = 0.0

        halfRepCount = 0
        isLookingForPositivePeak = nil
        lastStateChange = .distantPast

        velocitySum = 0.0
        ascendingSampleCount = 0
        currentInstantaneousVelocity = 0.0
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
            // 最初のアクション: ラックアップ時のブレを無視し、重力方向（下降）への動きからのみスタートする
            if isLeftArm {
                // 左腕の場合：プラス方向の動きを「バーを下ろす（descending）」と判定
                // (※デバイスの向き設定によっては +/- が逆になる場合があります)
                if activeAcc > peakThreshold {
                    isLookingForPositivePeak = false // 次は負のピーク（ボトムでの切り返し）を待つ
                    lastStateChange = now
                    currentPhase = .descending
                }
            } else {
                // 右腕の場合：マイナス方向の動きを「バーを下ろす（descending）」と判定
                if activeAcc < -peakThreshold {
                    isLookingForPositivePeak = true // 次は正のピーク（ボトムでの切り返し）を待つ
                    lastStateChange = now
                    currentPhase = .descending
                }
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
            
            // 平均速度（Mean Velocity）を算出
            if ascendingSampleCount > 0 {
                lastRepMeanVelocity = velocitySum / Double(ascendingSampleCount)
            } else {
                lastRepMeanVelocity = 0.0
            }
            
            // 次のRepのためにリセット
            velocitySum = 0.0
            ascendingSampleCount = 0
            currentInstantaneousVelocity = 0.0
            
            onRepDetected?()
        } else {
            currentPhase = .bottom
            // 上昇開始にあたって速度計算用変数を一度クリア（静止状態と仮定）
            velocitySum = 0.0
            ascendingSampleCount = 0
            currentInstantaneousVelocity = 0.0
        }
    }
}
