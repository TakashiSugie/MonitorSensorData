#if os(watchOS)
import SwiftUI

/// 結果画面 - セッション結果表示 + 保存
struct ResultView: View {
    
    @ObservedObject var motionManager: MotionManager
    @ObservedObject var workoutManager: WorkoutManager
    @State private var isSaved = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // エクササイズ名
            Text("Bench Press")
                .font(.caption)
                .foregroundStyle(.gray)
            
            // rep数結果
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(motionManager.repCount)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                
                Text("reps")
                    .font(.title3)
                    .foregroundStyle(.gray)
            }
            
            // 経過時間
            Text(workoutManager.formattedElapsedTime)
                .font(.caption)
                .foregroundStyle(.gray)
                .monospacedDigit()
            
            Spacer()
            
            // SAVEボタン
            if !isSaved {
                Button {
                    saveSession()
                } label: {
                    Text("SAVE")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                // 保存完了表示
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    
                    Text("Saved!")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .navigationBarBackButtonHidden(true)
    }
    
    private func saveSession() {
        // WorkoutSessionを作成して保存
        let session = WorkoutSession(
            repCount: motionManager.repCount,
            duration: workoutManager.elapsedTime
        )
        session.save()
        
        // センサーログを保存
        motionManager.sensorLogger.saveToFile()
        
        // HealthKitワークアウトを保存
        workoutManager.saveWorkout { success in
            print("ResultView: HealthKit save \(success ? "succeeded" : "failed")")
        }
        
        // ハプティクス
        HapticsManager.playGoalReached()
        
        withAnimation {
            isSaved = true
        }
    }
}
#endif
