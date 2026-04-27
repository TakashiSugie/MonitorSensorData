//
//  MotionManager.swift
//  BenchCoach Watch App
//
//  CoreMotion によるセンサーデータ取得と管理
//
//  ─── 修正ポイント ──────────────────────────────────────────────────
//
//  ❶ lastMotionTime のデータレース修正
//     motionQueue（書き込み）とメインスレッド（Timer での読み取り）が
//     同じ Date 変数に同時アクセスしていた。
//     → os_unfair_lock で保護し、専用のアクセサ経由でのみ読み書きする。
//
//  ❷ inactivityDuration を 10秒 → 30秒に延長
//     圏外時に watchOS がリソース節約でモーション処理を若干遅延させると、
//     10秒では容易に誤トリガーしてセッションが止まっていた。
//
//  ❸ DeviceMotion エラー時の自動リトライ
//     圏外などで nil motion（エラー）が返ったとき、従来は無視していた。
//     → 連続エラーが一定回数（5回）以上続いたら 1秒後に再起動する。
//
//  ─── デバッグログ（[SAMPLING] タグ） ─────────────────────────────
//  以下のログを出力し、実機ログで圏外時の挙動を追跡できる：
//  ・1秒ごとの実測サンプリングレート（目標 50Hz）
//  ・サンプル間隔が 60ms 超のギャップ警告
//  ・inactivityTimer の判定状態（5秒ごと）
//  ・モーションエラー発生 / リトライ
//  ──────────────────────────────────────────────────────────────────

import Foundation
import CoreMotion
import WatchKit
import os.lock
import os.log

// MARK: - デバッグログ用 Logger
private let motionLogger = Logger(subsystem: "com.repcount", category: "MotionManager")

class MotionManager: ObservableObject {
    
    // MARK: - Properties
    
    private let motionManager = CMMotionManager()
    
    /// センサー更新頻度（50Hz）
    private let updateInterval: TimeInterval = 1.0 / 50.0
    
    /// セット終了判定の閾値
    private let inactivityThreshold: Double = 0.05
    
    /// セット終了までの無動作時間（秒）
    /// ❷ 10秒 → 30秒に延長：圏外時の処理遅延による誤トリガーを防ぐ
    private let inactivityDuration: TimeInterval = 30.0
    
    // ❶ lastMotionTime のデータレース対策
    // motionQueue と メインスレッド（Timer）の両方からアクセスされるため
    // os_unfair_lock でガードする。直接変数にアクセスしないこと。
    private var _lastMotionTimeLock = os_unfair_lock()
    private var _lastMotionTime: Date = Date()
    
    private var lastMotionTime: Date {
        get {
            os_unfair_lock_lock(&_lastMotionTimeLock)
            defer { os_unfair_lock_unlock(&_lastMotionTimeLock) }
            return _lastMotionTime
        }
        set {
            os_unfair_lock_lock(&_lastMotionTimeLock)
            _lastMotionTime = newValue
            os_unfair_lock_unlock(&_lastMotionTimeLock)
        }
    }
    
    /// セット終了コールバック
    var onSetCompleted: (() -> Void)?
    
    /// センサーストリーマー（モニタリング用）
    var sensorStreamer: SensorStreamer?
    
    /// 無動作チェック用タイマー
    private var inactivityTimer: Timer?
    
    /// 開始時刻
    private var startTime: Date?
    
    /// センサーからのハードウェア基準時刻
    private var baseTimestamp: TimeInterval?
    
    // ❸ エラーリトライ管理
    /// 連続エラー回数カウンタ（motionQueue 上で読み書き）
    private var consecutiveErrorCount: Int = 0
    /// 連続エラーがこの回数を超えたらリトライ
    private let maxConsecutiveErrors: Int = 5
    /// リトライ中フラグ（二重リトライ防止）
    private var isRetrying: Bool = false
    /// リトライ時に repDetector を保持
    private weak var currentRepDetector: RepDetector?

    // ─── デバッグ計測用（motionQueue 上でのみアクセス）───
    /// 前回サンプルのハードウェアタイムスタンプ（ギャップ検出用）
    private var prevSampleTimestamp: TimeInterval? = nil
    /// 1秒ウィンドウ内のサンプル数
    private var samplingWindowCount: Int = 0
    /// 現在の計測ウィンドウ開始時刻
    private var samplingWindowStart: Date = Date()
    /// 累計サンプル数（motionQueue 上）
    private var totalSampleCount: Int = 0
    /// inactivityTimer のデバッグカウンタ（メインスレッド）
    private var inactivityDebugTickCount: Int = 0
    
    /// センサーデータ処理用の専用キュー（メインスレッドを占有しない）
    private let motionQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.repcount.motionQueue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()
    
    // MARK: - Public Methods
    
    /// センサーデータ取得を開始
    /// - Parameter repDetector: rep検出エンジン
    func startUpdates(repDetector: RepDetector) {
        guard motionManager.isDeviceMotionAvailable else {
            print("[MotionManager] DeviceMotion is not available.")
            return
        }
        
        startTime = Date()
        lastMotionTime = Date()
        baseTimestamp = nil
        consecutiveErrorCount = 0
        isRetrying = false
        currentRepDetector = repDetector

        // デバッグ計測リセット
        prevSampleTimestamp = nil
        samplingWindowCount = 0
        samplingWindowStart = Date()
        totalSampleCount = 0
        inactivityDebugTickCount = 0

        motionLogger.info("[SAMPLING] startUpdates 開始")
        print("[SAMPLING] startUpdates 開始")
        
        startDeviceMotionUpdates(repDetector: repDetector)
        
        // 無動作チェックタイマー開始（メインスレッドの RunLoop に登録）
        startInactivityTimer()
    }
    
    /// センサーデータ取得を停止
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        isRetrying = false
        currentRepDetector = nil
    }
    
    // MARK: - Private Methods
    
    /// DeviceMotion の登録処理（リトライ時に再利用）
    private func startDeviceMotionUpdates(repDetector: RepDetector) {
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self else { return }
            
            // ❸ motion が nil（エラー）の場合のリトライ処理
            guard let motion = motion else {
                self.consecutiveErrorCount += 1
                let errMsg = error?.localizedDescription ?? "unknown"
                motionLogger.warning("[SAMPLING] DeviceMotion error #\(self.consecutiveErrorCount): \(errMsg)")
                print("[SAMPLING] DeviceMotion error #\(self.consecutiveErrorCount): \(errMsg)")
                if self.consecutiveErrorCount >= self.maxConsecutiveErrors, !self.isRetrying {
                    self.isRetrying = true
                    motionLogger.error("[SAMPLING] \(self.maxConsecutiveErrors)回連続エラー → 1秒後にリトライ")
                    print("[SAMPLING] \(self.maxConsecutiveErrors)回連続エラー → 1秒後にリトライ")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        guard let self = self, let detector = self.currentRepDetector else { return }
                        self.motionManager.stopDeviceMotionUpdates()
                        self.consecutiveErrorCount = 0
                        self.isRetrying = false
                        motionLogger.info("[SAMPLING] リトライ: startDeviceMotionUpdates 再呼び出し")
                        print("[SAMPLING] リトライ: startDeviceMotionUpdates 再呼び出し")
                        self.startDeviceMotionUpdates(repDetector: detector)
                    }
                }
                return
            }
            
            // 正常なデータが来たらエラーカウントをリセット
            if self.consecutiveErrorCount > 0 {
                motionLogger.info("[SAMPLING] エラー解消（連続 \(self.consecutiveErrorCount) 回後）")
                print("[SAMPLING] エラー解消（連続 \(self.consecutiveErrorCount) 回後）")
            }
            self.consecutiveErrorCount = 0

            // ─── ギャップ検出 ────────────────────────────────────────
            // 前回サンプルとのハードウェア時刻差を計算し、60ms 超でギャップ警告
            let currentHWTime = motion.timestamp
            if let prev = self.prevSampleTimestamp {
                let gapMs = (currentHWTime - prev) * 1000.0
                if gapMs > 60.0 { // 期待値 20ms の 3倍
                    motionLogger.warning("[SAMPLING] ⚠️ ギャップ検出: \(String(format: "%.1f", gapMs))ms（通算 \(self.totalSampleCount) サンプル目）")
                    print("[SAMPLING] ⚠️ ギャップ検出: \(String(format: "%.1f", gapMs))ms（通算 \(self.totalSampleCount) サンプル目）")
                }
            }
            self.prevSampleTimestamp = currentHWTime

            // ─── 実測サンプリングレート（1秒ウィンドウ）─────────────
            self.samplingWindowCount += 1
            self.totalSampleCount += 1
            let now = Date()
            let windowElapsed = now.timeIntervalSince(self.samplingWindowStart)
            if windowElapsed >= 1.0 {
                let rate = Double(self.samplingWindowCount) / windowElapsed
                let status = rate < 40.0 ? "⚠️ 低下" : "✅ 正常"
                motionLogger.info("[SAMPLING] \(status) 実測レート: \(String(format: "%.1f", rate))Hz（目標50Hz、通算 \(self.totalSampleCount) サンプル）")
                print("[SAMPLING] \(status) 実測レート: \(String(format: "%.1f", rate))Hz（目標50Hz、通算 \(self.totalSampleCount) サンプル）")
                self.samplingWindowCount = 0
                self.samplingWindowStart = now
            }
            
            let acc = motion.userAcceleration
            var accY = acc.y
            
            // 手首の向きとクラウンの位置によるY軸の補正
            // Apple Watchは「左手/右クラウン」がデフォルトの基準向き。
            // それ以外の装着パターンの場合、画面の上下に対してセンサーのY軸が反転するため補正する。
            if #available(watchOS 3.0, *) {
                let device = WKInterfaceDevice.current()
                let isLeftWrist = device.wristLocation == .left
                let isCrownRight = device.crownOrientation == .right
                
                // 左手でクラウンが左、または右手でクラウンが右の場合はY軸を反転
                if (isLeftWrist && !isCrownRight) || (!isLeftWrist && isCrownRight) {
                    accY = -accY
                }
            }
            
            // rep検出エンジンにデータ供給
            repDetector.processAcceleration(accX: acc.x, accY: accY, accZ: acc.z)
            
            // 動作検出（セット終了判定用）
            // ❶ lastMotionTime への書き込みはロック付きアクセサ経由
            let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
            if magnitude > self.inactivityThreshold {
                self.lastMotionTime = Date()
            }
            
            // モニタリングサーバーへストリーミング
            if let streamer = self.sensorStreamer {
                if self.baseTimestamp == nil {
                    self.baseTimestamp = motion.timestamp
                }
                let hardwareTimestamp = motion.timestamp - self.baseTimestamp!
                
                streamer.addSample(
                    timestamp: hardwareTimestamp,
                    accX: acc.x,
                    accY: acc.y,
                    accZ: acc.z,
                    filteredAccY: repDetector.filteredAccY,
                    phase: repDetector.currentPhase.rawValue,
                    repCount: repDetector.repCount
                )
            }
        }
    }
    
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityDebugTickCount = 0
        // .common モードで登録することで、UI スクロール中でも Timer が止まらない
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // ❶ lastMotionTime の読み取りもロック付きアクセサ経由
            let elapsed = Date().timeIntervalSince(self.lastMotionTime)

            // 5秒ごとに inactivityTimer の状態をログ出力
            self.inactivityDebugTickCount += 1
            if self.inactivityDebugTickCount % 5 == 0 {
                let remaining = max(0, self.inactivityDuration - elapsed)
                motionLogger.info("[SAMPLING] inactivityTimer: 無動作 \(String(format: "%.1f", elapsed))秒 / 閾値 \(Int(self.inactivityDuration))秒（残 \(String(format: "%.1f", remaining))秒）")
                print("[SAMPLING] inactivityTimer: 無動作 \(String(format: "%.1f", elapsed))秒 / 閾値 \(Int(self.inactivityDuration))秒（残 \(String(format: "%.1f", remaining))秒）")
            }

            if elapsed >= self.inactivityDuration {
                motionLogger.warning("[SAMPLING] 🛑 inactivityDuration 超過 → onSetCompleted 発火")
                print("[SAMPLING] 🛑 inactivityDuration 超過 → onSetCompleted 発火")
                self.onSetCompleted?()
                self.inactivityTimer?.invalidate()
                self.inactivityTimer = nil
            }
        }
        // RunLoop.Mode.common に追加（スクロール中も動き続ける）
        RunLoop.main.add(inactivityTimer!, forMode: .common)
    }
}
