//
//  CSVLoader.swift
//  BenchCoach Watch AppTests
//
//  SensorMonitorで収集した実録CSVデータをUnit Testに読み込ませるためのローダー
//

import Foundation

struct SensorDataRow {
    let timestamp: TimeInterval // UNIXミリ秒(Date.now()由来を想定)
    let accX: Double
    let accY: Double
    let accZ: Double
}

class CSVLoader {
    
    /// テストバンドルに含まれる指定した名前のCSVファイルを読み込み、SensorDataRow の配列に変換します。
    static func load(fromResource name: String, bundle: Bundle) -> [SensorDataRow] {
        guard let url = bundle.url(forResource: name, withExtension: "csv") else {
            print("❌ CSV File not found: \(name).csv")
            return []
        }
        
        guard let content = try? String(contentsOf: url) else {
            print("❌ Failed to read content of: \(name).csv")
            return []
        }
        
        var rows: [SensorDataRow] = []
        let lines = content.components(separatedBy: .newlines)
        
        // ヘッダー行があればスキップする
        var startIndex = 0
        if let firstLine = lines.first, firstLine.lowercased().contains("acc") || firstLine.lowercased().contains("time") {
            startIndex = 1
        }
        
        for i in startIndex..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            
            // SensorMonitor の形式想定: timestamp,accX,accY,accZ,gyroX,gyroY,gyroZ,repPhase,repCount
            let columns = line.components(separatedBy: ",")
            if columns.count >= 4,
               let t = Double(columns[0]),
               let x = Double(columns[1]),
               let y = Double(columns[2]),
               let z = Double(columns[3]) {
                
                rows.append(SensorDataRow(timestamp: t, accX: x, accY: y, accZ: z))
            }
        }
        
        print("✅ Loaded \(rows.count) rows from \(name).csv")
        return rows
    }
}
