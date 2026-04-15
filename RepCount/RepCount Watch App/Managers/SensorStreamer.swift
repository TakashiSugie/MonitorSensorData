//
//  SensorStreamer.swift
//  BenchCoach Watch App
//
//  オフラインCSVデータの記録ロジック（旧ストリーマー）
//

import Foundation

class SensorStreamer {

    // MARK: - Configuration

    /// モニタリングサーバーのURL（サマリー送信などに使用）
    var serverURL: String = "https://repcount-monitor-ppcng5xypa-an.a.run.app"

    /// 送信バッチサイズ（この数のサンプルが溜まったらファイルへ書き込み）
    private let writeBatchSize: Int = 50

    // MARK: - State

    private var isStreaming: Bool = false
    private var sampleBuffer: [String] = []  // 文字列ベースに変更
    private var sendQueue = DispatchQueue(label: "com.repcount.streamer", qos: .utility)
    
    /// オフラインデータストア
    let offlineStore = OfflineDataStore()
    
    /// ユニークなユーザーID（サーバー側でデータを識別するために使用、サマリー送信用）
    var userID: String = "unknown"

    // MARK: - Initialization

    init() {
        // Network session is removed for sensor data because it is completely offline now.
    }

    // MARK: - Public Methods

    /// ストリーミング（ローカル保存）開始
    func start() {
        sampleBuffer.removeAll(keepingCapacity: true)
        isStreaming = true
        
        // オフラインCSVセッション開始
        offlineStore.startSession()
        
        print("[SensorStreamer] Started offline logging")
    }

    /// ストリーミング停止
    func stop() {
        if !isStreaming { return }
        isStreaming = false
        
        sendQueue.async { [weak self] in
            guard let self = self else { return }
            // 残りのバッファを書き込み
            if !self.sampleBuffer.isEmpty {
                let chunk = self.sampleBuffer.joined()
                self.offlineStore.writeChunk(chunk)
                self.sampleBuffer.removeAll()
            }
            // セッション終了
            self.offlineStore.endSession()
        }
        print("[SensorStreamer] Stopped offline logging")
    }

    /// センサーサンプルを追加
    func addSample(
        timestamp: Double,
        accX: Double,
        accY: Double,
        accZ: Double,
        filteredAccY: Double,
        phase: String,
        repCount: Int
    ) {
        guard isStreaming else { return }

        // CSVフォーマット化
        let line = String(format: "%.4f,%.6f,%.6f,%.6f,%.6f,%@,%d\n",
                          timestamp, accX, accY, accZ, filteredAccY, phase, repCount)

        sampleBuffer.append(line)

        if sampleBuffer.count >= writeBatchSize {
            let chunk = sampleBuffer.joined()
            // writeChunk 内で非同期キューに渡されるのでここでは直接呼ぶ
            offlineStore.writeChunk(chunk)
            sampleBuffer.removeAll(keepingCapacity: true)
        }
    }

    // MARK: - Summary Upload

    /// セッション結果（サマリー）をダッシュボードへ送信
    func sendSessionResult(session: WorkoutSession, averageVelocity: Double) {
        guard let url = URL(string: "\(serverURL)/api/sensor-data") else { return }

        let payload: [String: Any] = [
            "type": "session_result",
            "userID": userID,
            // サーバー側でパースしやすいようにISO8601フォーマットで送信
            "date": ISO8601DateFormatter().string(from: session.date),
            "weight": session.weight ?? 0,
            "reps": session.repCount,
            "duration": session.duration,
            "estimated1RM": session.estimated1RM ?? 0,
            "averageVelocity": averageVelocity
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let task = URLSession.shared.dataTask(with: request) { _, _, error in
                if let error = error {
                    print("[SensorStreamer] Failed to send session result: \(error)")
                } else {
                    print("[SensorStreamer] Sent session result successfully.")
                }
            }
            task.resume()
        } catch {
            print("[SensorStreamer] JSON Serialization error")
        }
    }
}
