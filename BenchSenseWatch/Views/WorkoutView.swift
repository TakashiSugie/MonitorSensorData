import SwiftUI

/// トレーニング中画面 - rep数表示 + 操作ボタン
struct WorkoutView: View {
    
    @ObservedObject var motionManager: MotionManager
    @ObservedObject var workoutManager: WorkoutManager
    @State private var showResult = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 8) {
            // 経過時間
            Text(workoutManager.formattedElapsedTime)
                .font(.caption)
                .foregroundStyle(.gray)
                .monospacedDigit()
            
            // 状態インジケーター
            Text(motionManager.currentState.rawValue)
                .font(.caption2)
                .foregroundStyle(.orange.opacity(0.7))
            
            Spacer()
            
            // rep数（大きく表示）
            VStack(spacing: 4) {
                Text("Rep")
                    .font(.caption)
                    .foregroundStyle(.gray)
                
                Text("\(motionManager.repCount)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.3), value: motionManager.repCount)
            }
            
            Spacer()
            
            // 操作ボタン
            HStack(spacing: 12) {
                // -1 ボタン
                Button {
                    motionManager.decrementRep()
                } label: {
                    Image(systemName: "minus")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // STOP ボタン
                Button {
                    stopWorkout()
                } label: {
                    Text("STOP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 44)
                        .background(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                
                // +1 ボタン
                Button {
                    motionManager.incrementRep()
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $showResult) {
            ResultView(
                motionManager: motionManager,
                workoutManager: workoutManager
            )
        }
        .onAppear {
            startWorkout()
        }
        .onChange(of: motionManager.isSetComplete) { _, isComplete in
            if isComplete {
                stopWorkout()
            }
        }
    }
    
    private func startWorkout() {
        workoutManager.startWorkout()
        motionManager.startTracking()
    }
    
    private func stopWorkout() {
        motionManager.stopTracking()
        workoutManager.endWorkout()
        showResult = true
    }
}
