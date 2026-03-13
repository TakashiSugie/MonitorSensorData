#if os(watchOS)
import Foundation
import CoreMotion
import Combine

/// ベンチプレスのrep検出状態マシン
enum RepState: String {
    case idle = "IDLE"
    case descending = "DESCENDING"
    case bottom = "BOTTOM"
    case ascending = "ASCENDING"
    case lockout = "LOCKOUT"
    case counted = "COUNTED"
}

/// CoreMotionを利用したベンチプレス動作検出マネージャー
class MotionManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var repCount: Int = 0
    @Published var isSetComplete: Bool = false
    @Published var currentState: RepState = .idle
    @Published var isTracking: Bool = false
    
    // MARK: - Core Motion
    
    private let motionManager = CMMotionManager()
    private let updateInterval: TimeInterval = 1.0 / 50.0  // 50Hz
    private let motionQueue = OperationQueue()
    
    // MARK: - Detection Parameters
    
    /// 下降検出しきい値 (accY < -threshold で下降判定)
    private let descendingThreshold: Double = 0.3
    /// 上昇検出しきい値 (accY > threshold で上昇判定)
    private let ascendingThreshold: Double = 0.3
    /// 最下点判定しきい値 (加速度の大きさがこの値以下で最下点)
    private let bottomThreshold: Double = 0.15
    /// ロックアウト判定しきい値 (安定状態)
    private let lockoutThreshold: Double = 0.1
    /// 二重カウント防止クールダウン (秒)
    private let cooldownDuration: TimeInterval = 0.8
    /// セット終了判定の静止しきい値
    private let setEndMotionThreshold: Double = 0.08
    /// セット終了判定の時間 (秒)
    private let setEndDuration: TimeInterval = 10.0
    
    // MARK: - Internal State
    
    private var lastRepTime: Date = .distantPast
    private var lastMotionTime: Date = Date()
    private var setEndTimer: Timer?
    
    // MARK: - Logger
    
    let sensorLogger = SensorLogger()
    
    // MARK: - Init
    
    init() {
        motionQueue.name = "com.benchsense.motion"
        motionQueue.maxConcurrentOperationCount = 1
        motionQueue.qualityOfService = .userInteractive
    }
    
    // MARK: - Public Methods
    
    /// モーションセンサーの取得を開始
    func startTracking() {
        guard motionManager.isDeviceMotionAvailable else {
            print("MotionManager: DeviceMotion is not available")
            return
        }
        
        reset()
        isTracking = true
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("MotionManager: Error - \(error.localizedDescription)")
                }
                return
            }
            self.processMotion(motion)
        }
        
        startSetEndMonitoring()
    }
    
    /// モーションセンサーの取得を停止
    func stopTracking() {
        motionManager.stopDeviceMotionUpdates()
        setEndTimer?.invalidate()
        setEndTimer = nil
        isTracking = false
    }
    
    /// 手動補正: +1
    func incrementRep() {
        repCount += 1
        HapticsManager.playRepSuccess()
    }
    
    /// 手動補正: -1
    func decrementRep() {
        if repCount > 0 {
            repCount -= 1
        }
    }
    
    /// 状態をリセット
    func reset() {
        repCount = 0
        isSetComplete = false
        currentState = .idle
        lastRepTime = .distantPast
        lastMotionTime = Date()
        sensorLogger.reset()
    }
    
    // MARK: - Motion Processing
    
    private func processMotion(_ motion: CMDeviceMotion) {
        // センサーログを記録
        sensorLogger.log(deviceMotion: motion)
        
        let acc = motion.userAcceleration
        let accY = acc.y
        let motionMagnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
        
        // モーション検出: 動きがあれば最終モーション時刻を更新
        if motionMagnitude > setEndMotionThreshold {
            lastMotionTime = Date()
        }
        
        // 状態マシンによるrep検出
        let result = detectRep(accY: accY, motionMagnitude: motionMagnitude)
        
        // UIの更新はメインスレッドで行う
        if result.stateChanged || result.repCounted {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                if result.stateChanged {
                    self.currentState = result.newState
                }
                
                if result.repCounted {
                    self.repCount += 1
                    HapticsManager.playRepSuccess()
                    
                    // カウント後にIDLEへ戻る
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                        self?.currentState = .idle
                    }
                }
                
                // モーション検出でセット完了フラグをリセット
                if motionMagnitude > self.setEndMotionThreshold && self.isSetComplete {
                    self.isSetComplete = false
                }
            }
        }
    }
    
    /// rep検出結果
    private struct DetectionResult {
        var stateChanged: Bool = false
        var newState: RepState = .idle
        var repCounted: Bool = false
    }
    
    private func detectRep(accY: Double, motionMagnitude: Double) -> DetectionResult {
        var result = DetectionResult()
        
        switch currentState {
        case .idle:
            // 下降開始を検出
            if accY < -descendingThreshold {
                result.stateChanged = true
                result.newState = .descending
            }
            
        case .descending:
            // 最下点を検出 (加速度が減少し安定)
            if motionMagnitude < bottomThreshold {
                result.stateChanged = true
                result.newState = .bottom
            }
            // 下降が途中で止まった場合はリセット
            if accY > ascendingThreshold {
                result.stateChanged = true
                result.newState = .idle
            }
            
        case .bottom:
            // 上昇開始を検出
            if accY > ascendingThreshold {
                result.stateChanged = true
                result.newState = .ascending
            }
            
        case .ascending:
            // ロックアウト（安定状態）を検出
            if motionMagnitude < lockoutThreshold {
                result.stateChanged = true
                result.newState = .lockout
            }
            
        case .lockout:
            // クールダウンチェック後にrep確定
            let now = Date()
            if now.timeIntervalSince(lastRepTime) >= cooldownDuration {
                result.stateChanged = true
                result.newState = .counted
                result.repCounted = true
                lastRepTime = now
            } else {
                result.stateChanged = true
                result.newState = .idle
            }
            
        case .counted:
            // .counted → .idle への遷移待ち（asyncAfterで処理）
            break
        }
        
        return result
    }
    
    // MARK: - Set End Detection
    
    private func startSetEndMonitoring() {
        setEndTimer?.invalidate()
        setEndTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(self.lastMotionTime)
            if elapsed >= self.setEndDuration && self.repCount > 0 && !self.isSetComplete {
                DispatchQueue.main.async {
                    self.isSetComplete = true
                    self.currentState = .idle
                }
                HapticsManager.playSetComplete()
            }
        }
    }
}
#endif
