//
//  MotionManager.swift
//  BenchCoach Watch App
//
//  CoreMotion によるセンサーデータ取得と管理
//

import Foundation
import CoreMotion
import WatchKit

class MotionManager: ObservableObject {
    
    // MARK: - Properties
    
    private let motionManager = CMMotionManager()
    
    /// センサー更新頻度（50Hz）
    private let updateInterval: TimeInterval = 1.0 / 50.0
    
    /// セット終了判定の閾値
    private let inactivityThreshold: Double = 0.05
    
    /// セット終了までの無動作時間（秒）
    private let inactivityDuration: TimeInterval = 10.0
    
    /// 最後に動きがあった時刻
    private var lastMotionTime: Date = Date()
    
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
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("[MotionManager] Error: \(error.localizedDescription)")
                }
                return
            }
            
            let acc = motion.userAcceleration
            let rot = motion.rotationRate
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
        
        // 無動作チェックタイマー開始
        startInactivityTimer()
    }
    
    /// センサーデータ取得を停止
    func stopUpdates() {
        motionManager.stopDeviceMotionUpdates()
        inactivityTimer?.invalidate()
        inactivityTimer = nil
    }
    

    
    // MARK: - Private Methods
    
    private func startInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let elapsed = Date().timeIntervalSince(self.lastMotionTime)
            if elapsed >= self.inactivityDuration {
                self.onSetCompleted?()
                self.inactivityTimer?.invalidate()
                self.inactivityTimer = nil
            }
        }
    }
}
