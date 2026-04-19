//
//  SensorLogger.swift
//  BenchCoach Watch App
//
//  CMDeviceMotion + CMAltimeter の全センサーデータを
//  高精度CSVへロギングするためのコア・エンジン（修正版）
//
//  ─── アーキテクチャ概要 ────────────────────────────────────────────
//
//  ❶ CMMotionManager は1インスタンスのみ（Apple制約）
//     → raw_acc は userAcceleration + gravity で計算（等価）
//
//  ❷ DeviceMotion (50Hz) がCSV書き込みのトリガー
//     → Altimeterは最新値を別途保持しておき、各行にマージする
//
//  ❸ ファイルI/OはセンサーキューとはQualityOfService の異なる
//     独立した ioQueue で実行し、センサークロックをブロックしない
//  ─────────────────────────────────────────────────────────────────

import Foundation
import CoreMotion
import os.lock

// MARK: - LatestAltimeterSnapshot

/// Altimeterの最新値をアトミックに保持するコンテナ
final class LatestAltimeterSnapshot {
    private var _lock = os_unfair_lock()
    private var _relativeAltitude: Double = 0
    private var _pressure: Double = 0

    struct AltimeterData {
        let relativeAltitude: Double
        let pressure: Double
    }

    func write(relativeAltitude: Double, pressure: Double) {
        os_unfair_lock_lock(&_lock)
        _relativeAltitude = relativeAltitude
        _pressure         = pressure
        os_unfair_lock_unlock(&_lock)
    }

    func read() -> AltimeterData {
        os_unfair_lock_lock(&_lock)
        defer { os_unfair_lock_unlock(&_lock) }
        return AltimeterData(relativeAltitude: _relativeAltitude, pressure: _pressure)
    }
}

// MARK: - SensorLogger

final class SensorLogger: ObservableObject {

    // MARK: - Published State

    @Published private(set) var isLogging: Bool = false
    @Published private(set) var sampleCount: Int = 0
    @Published private(set) var lastFilename: String = ""
    @Published private(set) var elapsedSeconds: Double = 0

    // MARK: - Configuration

    /// DeviceMotion サンプリングレート (50Hz)
    private let motionUpdateInterval: TimeInterval = 1.0 / 50.0

    /// CSVバッファのフラッシュ閾値（50行 ≈ 約1秒分）
    private let flushThreshold = 50

    // MARK: - CoreMotion
    // ⚠️ CMMotionManager はアプリ全体で1インスタンスだけ使うこと (Apple制約)
    private let motionManager = CMMotionManager()
    private let altimeter     = CMAltimeter()

    // MARK: - Queues

    private let motionQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.benchcoach.logger.motion"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .userInteractive
        return q
    }()

    private let altimeterQueue: OperationQueue = {
        let q = OperationQueue()
        q.name = "com.benchcoach.logger.altimeter"
        q.maxConcurrentOperationCount = 1
        q.qualityOfService = .utility
        return q
    }()

    /// FileI/O専用キュー（センサーキューをブロックしない）
    private let ioQueue = DispatchQueue(
        label: "com.benchcoach.logger.io",
        qos: .utility
    )

    // MARK: - State

    private let altimeterSnapshot = LatestAltimeterSnapshot()
    private var csvBuffer: [String] = []
    private var fileHandle: FileHandle?
    private var baseTimestamp: TimeInterval?

    private var displayTimer: Timer?
    private var logStartTime: Date?
    
    private var uiSampleCount = 0  // ioQueueのカウントをUIに反映するため別途追跡

    // MARK: - CSV Header

    private let csvHeader =
        "timestamp," +
        "raw_acc_x,raw_acc_y,raw_acc_z," +
        "user_acc_x,user_acc_y,user_acc_z," +
        "gravity_x,gravity_y,gravity_z," +
        "attitude_roll,attitude_pitch,attitude_yaw," +
        "gyro_x,gyro_y,gyro_z," +
        "relative_altitude,pressure," +
        "vertical_acc\n"

    // MARK: - Public API

    func startLogging() {
        guard !isLogging else { return }

        baseTimestamp = nil
        csvBuffer.removeAll(keepingCapacity: true)
        uiSampleCount = 0

        openNewCSVFile()
        startAltimeter()       // モーションより先に起動しておく
        startDeviceMotion()    // DeviceMotionが50Hzトリガー

        logStartTime = Date()
        startDisplayTimer()

        DispatchQueue.main.async { self.isLogging = true }
        print("[SensorLogger] Started → \(lastFilename)")
    }

    func stopLogging() {
        guard isLogging else { return }

        motionManager.stopDeviceMotionUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        stopDisplayTimer()

        ioQueue.async { [weak self] in
            guard let self = self else { return }
            self.flushBuffer(force: true)
            try? self.fileHandle?.synchronize()
            try? self.fileHandle?.close()
            self.fileHandle = nil
            DispatchQueue.main.async {
                self.isLogging = false
                print("[SensorLogger] Stopped. \(self.uiSampleCount) samples written.")
            }
        }
    }

    // MARK: - Private: File

    private func openNewCSVFile() {
        let fm = FileManager.default
        // OfflineDataStore と同じディレクトリに保存 → SavedDataView で表示・送信できる
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("SensorData", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "sensorlog_\(formatter.string(from: Date())).csv"
        let fileURL  = dir.appendingPathComponent(filename)

        fm.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            print("[SensorLogger] Failed to open file for writing")
            return
        }
        handle.write(Data(csvHeader.utf8))
        fileHandle = handle

        DispatchQueue.main.async { self.lastFilename = filename }
    }

    // MARK: - Private: Sensors

    private func startDeviceMotion() {
        guard motionManager.isDeviceMotionAvailable else {
            print("[SensorLogger] DeviceMotion not available")
            return
        }
        motionManager.deviceMotionUpdateInterval = motionUpdateInterval
        // xArbitraryCorrectedZVertical: ジャイロドリフトをコンパスで補正
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryCorrectedZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error { print("[SensorLogger] DeviceMotion error: \(error)") }
                return
            }

            // 初回サンプルでハードウェア基準タイムスタンプを確定
            if self.baseTimestamp == nil {
                self.baseTimestamp = motion.timestamp
            }
            let t = motion.timestamp - self.baseTimestamp!

            let u = motion.userAcceleration
            let g = motion.gravity
            let a = motion.attitude
            let r = motion.rotationRate

            // raw_acc = userAcceleration + gravity（等価変換）
            let rx = u.x + g.x
            let ry = u.y + g.y
            let rz = u.z + g.z

            // 鉛直加速度 = dot(userAcc, gravityUnit)
            let gNorm = sqrt(g.x*g.x + g.y*g.y + g.z*g.z)
            let verticalAcc: Double = gNorm > 1e-9
                ? (u.x*g.x + u.y*g.y + u.z*g.z) / gNorm
                : 0

            // Altimeterの最新値をマージ
            let alt = self.altimeterSnapshot.read()

            let row = String(format:
                "%.6f,"   +
                "%.8f,%.8f,%.8f,"  +
                "%.8f,%.8f,%.8f,"  +
                "%.8f,%.8f,%.8f,"  +
                "%.8f,%.8f,%.8f,"  +
                "%.8f,%.8f,%.8f,"  +
                "%.6f,%.4f,"       +
                "%.8f\n",
                t,
                rx, ry, rz,
                u.x, u.y, u.z,
                g.x, g.y, g.z,
                a.roll, a.pitch, a.yaw,
                r.x, r.y, r.z,
                alt.relativeAltitude, alt.pressure,
                verticalAcc
            )

            self.ioQueue.async {
                self.csvBuffer.append(row)
                self.uiSampleCount += 1
                if self.csvBuffer.count >= self.flushThreshold {
                    self.flushBuffer(force: false)
                    let count = self.uiSampleCount
                    DispatchQueue.main.async { self.sampleCount = count }
                }
            }
        }
    }

    private func startAltimeter() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else {
            print("[SensorLogger] Altimeter not available")
            return
        }
        altimeter.startRelativeAltitudeUpdates(to: altimeterQueue) { [weak self] data, error in
            guard let self = self, let data = error == nil ? data : nil else { return }
            // kPa → hPa に換算
            self.altimeterSnapshot.write(
                relativeAltitude: data.relativeAltitude.doubleValue,
                pressure: data.pressure.doubleValue * 10.0
            )
        }
    }

    // MARK: - Private: Buffer I/O (ioQueue上で呼ぶこと)

    private func flushBuffer(force: Bool) {
        guard force || csvBuffer.count >= flushThreshold else { return }
        guard let handle = fileHandle, !csvBuffer.isEmpty else { return }
        let data = Data(csvBuffer.joined().utf8)
        csvBuffer.removeAll(keepingCapacity: true)
        handle.write(data)
    }

    // MARK: - Private: Display Timer

    private func startDisplayTimer() {
        displayTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.logStartTime else { return }
            self.elapsedSeconds = Date().timeIntervalSince(start)
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }
}
