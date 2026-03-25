//
//  WorkoutView.swift
//  BenchSense_r1 Watch App
//
//  トレーニング画面 - カウンター & 操作ボタン
//

import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 4) {
            // デバッグ情報
            VStack(spacing: 1) {
                Text("fAccY: \(workoutManager.currentFilteredAccY, specifier: "%.3f")  [\(workoutManager.currentPhase)]")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            Spacer()
            
            // トレーニング情報 (中央配置)
            VStack(spacing: 8) {
                // Rep表示 (数字中心、右に"Rep")
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(workoutManager.repCount)")
                        .font(.system(size: 60, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: workoutManager.repCount)
                    
                    Text("Rep")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                // VBT (挙上速度) 常時表示
                Text(String(format: "VBT: %.2f m/s", workoutManager.lastRepVelocity))
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.white)
                
                // 経過時間
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .foregroundColor(.orange)
                    Text(formatTime(workoutManager.elapsedTime))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // 操作ボタン
            HStack(spacing: 8) {
                // -1 ボタン
                Button(action: {
                    workoutManager.decrementRep()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // STOP ボタン
                Button(action: {
                    workoutManager.stopWorkout()
                }) {
                    Text("STOP")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // +1 ボタン
                Button(action: {
                    workoutManager.incrementRep()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutManager())
}
