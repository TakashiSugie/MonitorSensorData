import Foundation
import HealthKit

/// HealthKitワークアウトセッション管理マネージャー
class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isWorkoutActive: Bool = false
    @Published var elapsedTime: TimeInterval = 0
    
    // MARK: - HealthKit
    
    let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // MARK: - Timer
    
    private var timer: Timer?
    private var startDate: Date?
    
    // MARK: - Authorization
    
    /// HealthKitの権限をリクエスト
    func requestAuthorization() {
        let typesToShare: Set = [
            HKQuantityType.workoutType()
        ]
        
        let typesToRead: Set = [
            HKQuantityType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("WorkoutManager: Authorization failed - \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Workout Session
    
    /// ワークアウトセッションを開始
    func startWorkout() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(
                healthStore: healthStore,
                configuration: configuration
            )
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            let startDate = Date()
            self.startDate = startDate
            
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("WorkoutManager: Begin collection failed - \(error.localizedDescription)")
                }
            }
            
            isWorkoutActive = true
            startTimer()
            
        } catch {
            print("WorkoutManager: Failed to start workout - \(error.localizedDescription)")
        }
    }
    
    /// ワークアウトセッションを終了
    func endWorkout() {
        guard let workoutSession = workoutSession else { return }
        
        workoutSession.end()
        stopTimer()
        isWorkoutActive = false
    }
    
    /// ワークアウトを保存
    func saveWorkout(completion: @escaping (Bool) -> Void) {
        guard let workoutBuilder = workoutBuilder else {
            completion(false)
            return
        }
        
        workoutBuilder.endCollection(withEnd: Date()) { success, error in
            if let error = error {
                print("WorkoutManager: End collection failed - \(error.localizedDescription)")
                completion(false)
                return
            }
            
            workoutBuilder.finishWorkout { workout, error in
                if let error = error {
                    print("WorkoutManager: Finish workout failed - \(error.localizedDescription)")
                    completion(false)
                } else {
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - Timer
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startDate = self.startDate else { return }
            self.elapsedTime = Date().timeIntervalSince(startDate)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    /// 経過時間を MM:SS 形式でフォーマット
    var formattedElapsedTime: String {
        let minutes = Int(elapsedTime) / 60
        let seconds = Int(elapsedTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        DispatchQueue.main.async {
            self.isWorkoutActive = toState == .running
        }
    }
    
    func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        print("WorkoutManager: Session failed - \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // イベントコレクション処理（MVP では未使用）
    }
    
    func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        // データコレクション処理（MVP では未使用）
    }
}
