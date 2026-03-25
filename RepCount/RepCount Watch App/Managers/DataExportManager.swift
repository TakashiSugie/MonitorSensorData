//
//  DataExportManager.swift
//  BenchCoach Watch App
//
//  Premiumユーザー向けデータ出力ユーティリティ（CSVエクスポートなど）
//

import Foundation

class DataExportManager {
    
    /// 単一セッションのデータをCSV文字列として生成
    static func generateCSVSingleSession(session: WorkoutSession) -> String {
        var csvString = "Rep,Velocity (m/s),Weight (kg),Date,Time\n"
        
        // 日付フォーマット
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: session.date)
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm:ss"
        let timeString = timeFormatter.string(from: session.date)
        
        let weightStr = session.weight != nil ? "\(session.weight!)" : "0"
        
        for (index, velocity) in session.velocities.enumerated() {
            let repNum = index + 1
            let velStr = String(format: "%.3f", velocity)
            
            let row = "\(repNum),\(velStr),\(weightStr),\(dateString),\(timeString)\n"
            csvString.append(row)
        }
        
        return csvString
    }
    
    /// 全履歴データを1つのCSVにまとめて出力
    static func generateCSVAllHistory(sessions: [WorkoutSession]) -> String {
        var csvString = "SessionID,Exercise,Date,Time,Weight (kg),Duration (s),RepNum,Velocity (m/s)\n"
        
        let dFormatter = DateFormatter()
        dFormatter.dateFormat = "yyyy-MM-dd"
        
        let tFormatter = DateFormatter()
        tFormatter.dateFormat = "HH:mm:ss"
        
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let sessionID = session.id.uuidString.prefix(8)
            let dateStr = dFormatter.string(from: session.date)
            let timeStr = tFormatter.string(from: session.date)
            let weightStr = session.weight != nil ? "\(session.weight!)" : "0"
            let durationStr = String(format: "%.0f", session.duration)
            
            if session.velocities.isEmpty {
                // No VBT data for this session
                let row = "\(sessionID),\(session.exerciseType),\(dateStr),\(timeStr),\(weightStr),\(durationStr),0,0.0\n"
                csvString.append(row)
            } else {
                for (index, velocity) in session.velocities.enumerated() {
                    let repNum = index + 1
                    let velStr = String(format: "%.3f", velocity)
                    
                    let row = "\(sessionID),\(session.exerciseType),\(dateStr),\(timeStr),\(weightStr),\(durationStr),\(repNum),\(velStr)\n"
                    csvString.append(row)
                }
            }
        }
        
        return csvString
    }
    
    /// 一時ディレクトリにCSVファイルとして保存し、そのURLを返す（ShareLink等で使用）
    static func createTempCSVFile(csvString: String, filename: String = "WorkoutData.csv") -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        do {
            try csvString.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("[DataExportManager] Error writing CSV to temp file: \(error)")
            return nil
        }
    }
}
