import Foundation

/// ワークアウトセッションのデータモデル
struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let date: Date
    let exerciseType: String
    var repCount: Int
    var duration: TimeInterval
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        exerciseType: String = "Bench Press",
        repCount: Int = 0,
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.date = date
        self.exerciseType = exerciseType
        self.repCount = repCount
        self.duration = duration
    }
}

// MARK: - Persistence

extension WorkoutSession {
    
    private static let storageKey = "repcount_sessions"
    
    /// 全セッションを取得
    static func loadAll() -> [WorkoutSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }
        return (try? JSONDecoder().decode([WorkoutSession].self, from: data)) ?? []
    }
    
    /// セッションを保存
    func save() {
        var sessions = WorkoutSession.loadAll()
        sessions.append(self)
        if let data = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
