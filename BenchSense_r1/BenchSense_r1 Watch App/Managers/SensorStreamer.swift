//
//  SensorStreamer.swift
//  BenchSense_r1 Watch App
//
//  センサーデータをMacのモニタリングサーバーにHTTP POSTで送信
//

import Foundation

class SensorStreamer {
    
    // MARK: - Configuration
    
    /// モニタリングサーバーのホスト（MacのIPアドレス）
    /// ⚠️ 実機テスト時にMacのIPアドレスに書き換えてください
    var serverHost: String = "192.168.150.90"
    var serverPort: Int = 8765
    
    /// 送信バッチサイズ（この数のサンプルが溜まったら送信）
    private let batchSize: Int = 10
    
    // MARK: - State
    
    private var isStreaming: Bool = false
    private var sampleBuffer: [[String: Any]] = []
    private let session: URLSession
    private var sendQueue = DispatchQueue(label: "com.benchsense.streamer", qos: .utility)
    
    // MARK: - Initialization
    
    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public Methods
    
    /// ストリーミング開始
    func start() {
        sampleBuffer.removeAll()
        isStreaming = true
        print("[SensorStreamer] Started streaming to \(serverHost):\(serverPort)")
    }
    
    /// ストリーミング停止
    func stop() {
        isStreaming = false
        // 残りのバッファを送信
        if !sampleBuffer.isEmpty {
            flushBuffer()
        }
        print("[SensorStreamer] Stopped streaming")
    }
    
    /// センサーサンプルを追加
    /// - Parameters:
    ///   - timestamp: セッション開始からの経過時間
    ///   - accX: X軸加速度
    ///   - accY: Y軸加速度
    ///   - accZ: Z軸加速度
    ///   - filteredAccY: フィルタ済みY軸加速度
    ///   - phase: RepDetectorの現在フェーズ
    ///   - repCount: 現在のrepカウント
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
        
        let sample: [String: Any] = [
            "t": timestamp,
            "ax": accX,
            "ay": accY,
            "az": accZ,
            "fay": filteredAccY,
            "phase": phase,
            "rep": repCount
        ]
        
        sampleBuffer.append(sample)
        
        if sampleBuffer.count >= batchSize {
            flushBuffer()
        }
    }
    
    // MARK: - Private Methods
    
    private func flushBuffer() {
        let samplesToSend = sampleBuffer
        sampleBuffer.removeAll()
        
        sendQueue.async { [weak self] in
            self?.sendBatch(samplesToSend)
        }
    }
    
    private func sendBatch(_ samples: [[String: Any]]) {
        guard let url = URL(string: "http://\(serverHost):\(serverPort)/api/sensor-data") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["samples": samples]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            return
        }
        
        let task = session.dataTask(with: request) { _, response, error in
            // サイレントに失敗を処理（パフォーマンス重視）
            if let error = error {
                // ネットワークエラーは頻繁に出る可能性があるので、詳細ログは省略
                _ = error
            }
        }
        task.resume()
    }
}
