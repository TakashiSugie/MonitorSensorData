//
//  WorkoutManager.swift
//  BenchSense_r1 Watch App
//
//  HealthKit ワークアウトセッション管理 & 全体制御
//

import Foundation
import HealthKit
import Combine

/// アプリの画面状態
enum AppState {
    case home
    case workout
    case result
}

class WorkoutManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var appState: AppState = .home
    @Published var repCount: Int = 0
    @Published var elapsedTime: TimeInterval = 0
    @Published var isActive: Bool = false
    
    // MARK: - HealthKit
    
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?
    
    // MARK: - Motion & Detection
    
    let motionManager = MotionManager()
    let repDetector = RepDetector()
    
    // MARK: - Timing
    
    private var workoutStartTime: Date?
    private var timer: Timer?
    
    // MARK: - Session Result
    
    private(set) var lastSessionDuration: TimeInterval = 0
    private(set) var lastSessionRepCount: Int = 0
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        requestAuthorization()
        setupCallbacks()
    }
    
    // MARK: - Public Methods
    
    /// ワークアウト開始
    func startWorkout() {
        repDetector.reset()
        repCount = 0
        elapsedTime = 0
        workoutStartTime = Date()
        isActive = true
        appState = .workout
        
        // HealthKit セッション開始
        startHealthKitSession()
        
        // モーション取得開始
        motionManager.startUpdates(repDetector: repDetector)
        
        // タイマー開始
        startTimer()
    }
    
    /// ワークアウト停止
    func stopWorkout() {
        isActive = false
        
        // 結果を保存
        lastSessionDuration = elapsedTime
        lastSessionRepCount = repCount
        
        // モーション停止
        motionManager.stopUpdates()
        
        // タイマー停止
        timer?.invalidate()
        timer = nil
        
        // HealthKit セッション終了
        endHealthKitSession()
        
        // 結果画面へ
        appState = .result
        
        // セット完了の振動
        HapticManager.playSetComplete()
    }
    
    /// 手動 rep +1
    func incrementRep() {
        repDetector.addRep()
        repCount = repDetector.repCount
    }
    
    /// 手動 rep -1
    func decrementRep() {
        repDetector.removeRep()
        repCount = repDetector.repCount
    }
    
    /// セッションを保存してホームに戻る
    func saveAndReturn() {
        let session = WorkoutSession(
            date: workoutStartTime ?? Date(),
            exerciseType: "Bench Press",
            repCount: lastSessionRepCount,
            duration: lastSessionDuration
        )
        SessionStore.saveSession(session)
        returnToHome()
    }
    
    /// 保存せずにホームに戻る
    func returnToHome() {
        appState = .home
    }
    
    // MARK: - Private Methods
    
    private func setupCallbacks() {
        // rep検出コールバック
        repDetector.onRepDetected = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.repCount = self.repDetector.repCount
                HapticManager.playRepSuccess()
            }
        }
        
        // セット終了コールバック
        motionManager.onSetCompleted = { [weak self] in
            DispatchQueue.main.async {
                guard let self = self, self.isActive else { return }
                self.stopWorkout()
            }
        }
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let start = self.workoutStartTime else { return }
            self.elapsedTime = Date().timeIntervalSince(start)
        }
    }
    
    // MARK: - HealthKit
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType()
        ]
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType()
        ]
        
        healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead) { success, error in
            if let error = error {
                print("[WorkoutManager] HealthKit auth error: \(error.localizedDescription)")
            }
        }
    }
    
    private func startHealthKitSession() {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .traditionalStrengthTraining
        configuration.locationType = .indoor
        
        do {
            workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            workoutBuilder = workoutSession?.associatedWorkoutBuilder()
            
            workoutSession?.delegate = self
            workoutBuilder?.delegate = self
            
            workoutBuilder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: configuration
            )
            
            let startDate = Date()
            workoutSession?.startActivity(with: startDate)
            workoutBuilder?.beginCollection(withStart: startDate) { success, error in
                if let error = error {
                    print("[WorkoutManager] Failed to begin collection: \(error.localizedDescription)")
                }
            }
        } catch {
            print("[WorkoutManager] Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    private func endHealthKitSession() {
        workoutSession?.end()
        workoutBuilder?.endCollection(withEnd: Date()) { [weak self] success, error in
            self?.workoutBuilder?.finishWorkout { workout, error in
                if let error = error {
                    print("[WorkoutManager] Failed to finish workout: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - HKWorkoutSessionDelegate

extension WorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didChangeTo toState: HKWorkoutSessionState,
                        from fromState: HKWorkoutSessionState,
                        date: Date) {
        // 必要に応じてログ出力
        print("[WorkoutManager] Session state: \(fromState.rawValue) -> \(toState.rawValue)")
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession,
                        didFailWithError error: Error) {
        print("[WorkoutManager] Session failed: \(error.localizedDescription)")
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate

extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        // イベント収集時
    }
    
    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder,
                        didCollectDataOf collectedTypes: Set<HKSampleType>) {
        // データ収集時
    }
}
