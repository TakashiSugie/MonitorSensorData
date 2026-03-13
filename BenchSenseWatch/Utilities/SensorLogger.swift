import Foundation
import CoreMotion

/// センサーデータをCSV形式で記録するロガー
class SensorLogger {
    
    private var logEntries: [String] = []
    private let header = "timestamp,accX,accY,accZ,rotX,rotY,rotZ"
    
    /// ログをリセット
    func reset() {
        logEntries.removeAll()
    }
    
    /// センサーデータを記録
    func log(deviceMotion: CMDeviceMotion) {
        let timestamp = Date().timeIntervalSince1970
        let acc = deviceMotion.userAcceleration
        let rot = deviceMotion.rotationRate
        
        let entry = String(
            format: "%.4f,%.4f,%.4f,%.4f,%.4f,%.4f,%.4f",
            timestamp,
            acc.x, acc.y, acc.z,
            rot.x, rot.y, rot.z
        )
        logEntries.append(entry)
    }
    
    /// CSVファイルとしてドキュメントディレクトリに保存
    @discardableResult
    func saveToFile() -> URL? {
        let csv = ([header] + logEntries).joined(separator: "\n")
        
        guard let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first else {
            return nil
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "sensor_log_\(dateFormatter.string(from: Date())).csv"
        let fileURL = documentsDir.appendingPathComponent(filename)
        
        do {
            try csv.write(to: fileURL, atomically: true, encoding: .utf8)
            print("SensorLogger: Saved to \(fileURL.path)")
            return fileURL
        } catch {
            print("SensorLogger: Failed to save - \(error.localizedDescription)")
            return nil
        }
    }
    
    /// エントリ数を取得
    var entryCount: Int {
        logEntries.count
    }
}
