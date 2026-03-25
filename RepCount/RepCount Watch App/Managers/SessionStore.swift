//
//  SessionStore.swift
//  BenchCoach Watch App
//
//  セッションの永続化（UserDefaults + Codable）
//

import Foundation

class SessionStore {
    
    private static let storageKey = "com.repcount.sessions"
    
    /// 全セッションを取得
    static func loadSessions() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([WorkoutSession].self, from: data)
        } catch {
            print("[SessionStore] Failed to load sessions: \(error)")
            return []
        }
    }
    
    /// セッションを保存
    static func saveSession(_ session: WorkoutSession) {
        var sessions = loadSessions()
        sessions.insert(session, at: 0) // 新しいものを先頭に
        saveSessions(sessions)
    }
    
    /// 全セッションを保存
    private static func saveSessions(_ sessions: [WorkoutSession]) {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[SessionStore] Failed to save sessions: \(error)")
        }
    }
    
    /// セッションを削除
    static func deleteSession(id: UUID) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
    }
    
    /// 全セッションを削除
    static func deleteAll() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
