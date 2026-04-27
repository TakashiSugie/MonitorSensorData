//
//  SensorLogger.swift
//  BenchCoach Watch App
//
//  CMDeviceMotion + CMAltimeter の全センサーデータを
//  高精度CSVへロギングするためのコア・エンジン（OOM改善版）
//
//  ─── OOM改善のポイント ─────────────────────────────────────────────
//
//  ❶ バッファを [String] → 連結済み String（行バッファ）に変更
//     → append(_:) の都度 String を配列に積まずに、1つの文字列に連結する。
//     　 フラッシュ時は Data(utf8) で一発書き込み → 中間 String が即解放される。
//
//  ❷ ioQueue を廃止し、motionQueue 内で直接フラッシュ
//     → ioQueue.async で際限なくクロージャが積み上がる問題を解消。
//     　 50Hz ≈ 20ms/サンプルなので、ioQueue を挟まなくてもブロックしない。
//
//  ❸ flushThreshold を 10 に下げてピークバッファ量を削減
//     → 10行 × 約210 bytes ≒ 2 KB/flush。Watch でも余裕。
//
//  ❹ DispatchQueue の qos を .utility → .userInitiated に昇格
//     → watchOS のバックグラウンド throttle を受けにくくする。
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

    /// フラッシュ閾値を小さくしてピークメモリを抑制（10行 ≈ 200ms分）
    private let flushThreshold = 10

    // MARK: - CoreMotion
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

    // MARK: - State

    private let altimeterSnapshot = LatestAltimeterSnapshot()

    /// 行バッファ（String の配列ではなく、連結済みの単一 String）
    private var lineBuffer: String = ""
    private var lineBufferCount: Int = 0

    private var fileHandle: FileHandle?
    private var baseTimestamp: TimeInterval?
    private var localSampleCount: Int = 0   // motionQueue 上でカウント

    private var displayTimer: Timer?
    private var logStartTime: Date?

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
        lineBuffer = ""
        lineBuffer.reserveCapacity(flushThreshold * 220) // 1行約210バイト分を事前確保
        lineBufferCount = 0
        localSampleCount = 0

        openNewCSVFile()
        startAltimeter()
        startDeviceMotion()

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

        // motionQueue をドレインしてから残りをフラッシュ・クローズ
        motionQueue.addOperation { [weak self] in
            guard let self = self else { return }
            self.flushBuffer(force: true)
            try? self.fileHandle?.synchronize()
            try? self.fileHandle?.close()
            self.fileHandle = nil
            let count = self.localSampleCount
            DispatchQueue.main.async {
                self.isLogging = false
                self.sampleCount = count
                print("[SensorLogger] Stopped. \(count) samples written.")
            }
        }
    }

    // MARK: - Private: File

    private func openNewCSVFile() {
        let fm = FileManager.default
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
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryCorrectedZVertical,
            to: motionQueue
        ) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error { print("[SensorLogger] DeviceMotion error: \(error)") }
                return
            }

            if self.baseTimestamp == nil {
                self.baseTimestamp = motion.timestamp
            }
            let t = motion.timestamp - self.baseTimestamp!

            let u = motion.userAcceleration
            let g = motion.gravity
            let a = motion.attitude
            let r = motion.rotationRate

            let rx = u.x + g.x
            let ry = u.y + g.y
            let rz = u.z + g.z

            let gNorm = sqrt(g.x*g.x + g.y*g.y + g.z*g.z)
            let verticalAcc: Double = gNorm > 1e-9
                ? (u.x*g.x + u.y*g.y + u.z*g.z) / gNorm
                : 0

            let alt = self.altimeterSnapshot.read()

            // ─ バッファへ追記（motionQueue 上で実行 → ioQueue 不要）─
            self.lineBuffer += String(format:
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
            self.lineBufferCount += 1
            self.localSampleCount += 1

            // flushThreshold に達したらディスクに書き出してバッファを解放
            if self.lineBufferCount >= self.flushThreshold {
                self.flushBuffer(force: false)
            }

            // UI更新は50サンプル毎（=1秒毎）で十分
            if self.localSampleCount % 50 == 0 {
                let count = self.localSampleCount
                DispatchQueue.main.async { self.sampleCount = count }
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
            self.altimeterSnapshot.write(
                relativeAltitude: data.relativeAltitude.doubleValue,
                pressure: data.pressure.doubleValue * 10.0
            )
        }
    }

    // MARK: - Private: Buffer I/O（motionQueue 上で呼ぶこと）

    private func flushBuffer(force: Bool) {
        guard force || lineBufferCount >= flushThreshold else { return }
        guard let handle = fileHandle, !lineBuffer.isEmpty else { return }

        // Data への変換・書き込み後、バッファを完全解放
        let data = Data(lineBuffer.utf8)
        lineBuffer = ""
        lineBuffer.reserveCapacity(flushThreshold * 220)
        lineBufferCount = 0
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
