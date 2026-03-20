//
//  MotionManager.swift
//  BenchSense_r1 Watch App
//
//  CoreMotion によるセンサーデータ取得と管理
//

import Foundation
import CoreMotion

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
    
    /// センサーログ（CSV）
    private var sensorLog: [(timestamp: TimeInterval, accX: Double, accY: Double, accZ: Double, rotX: Double, rotY: Double, rotZ: Double)] = []
    
    /// ログ記録の有効化
    var isLoggingEnabled: Bool = false
    
    /// 開始時刻
    private var startTime: Date?
    
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
        sensorLog.removeAll()
        
        motionManager.deviceMotionUpdateInterval = updateInterval
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    print("[MotionManager] Error: \(error.localizedDescription)")
                }
                return
            }
            
            let acc = motion.userAcceleration
            let rot = motion.rotationRate
            
            // rep検出エンジンにデータ供給
            repDetector.processAcceleration(accX: acc.x, accY: acc.y, accZ: acc.z)
            
            // 動作検出（セット終了判定用）
            let magnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)
            if magnitude > self.inactivityThreshold {
                self.lastMotionTime = Date()
            }
            
            // センサーログ記録
            if self.isLoggingEnabled, let start = self.startTime {
                let timestamp = Date().timeIntervalSince(start)
                self.sensorLog.append((
                    timestamp: timestamp,
                    accX: acc.x, accY: acc.y, accZ: acc.z,
                    rotX: rot.x, rotY: rot.y, rotZ: rot.z
                ))
            }
            
            // モニタリングサーバーへストリーミング
            if let streamer = self.sensorStreamer, let start = self.startTime {
                let timestamp = Date().timeIntervalSince(start)
                streamer.addSample(
                    timestamp: timestamp,
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
    
    /// センサーログをCSV文字列として取得
    func exportLogAsCSV() -> String {
        var csv = "timestamp,accX,accY,accZ,rotX,rotY,rotZ\n"
        for entry in sensorLog {
            csv += String(format: "%.4f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f\n",
                          entry.timestamp, entry.accX, entry.accY, entry.accZ,
                          entry.rotX, entry.rotY, entry.rotZ)
        }
        return csv
    }
    
    /// センサーログをファイルに保存
    func saveLogToFile() -> URL? {
        let csv = exportLogAsCSV()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "sensor_log_\(formatter.string(from: Date())).csv"
        
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileURL = dir.appendingPathComponent(filename)
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            print("[MotionManager] Log saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("[MotionManager] Failed to save log: \(error)")
            return nil
        }
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
