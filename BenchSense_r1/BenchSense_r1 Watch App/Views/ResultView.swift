//
//  ResultView.swift
//  BenchSense_r1 Watch App
//
//  結果画面 - rep数表示 & SAVE
//

import SwiftUI

struct ResultView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) { // 12 -> 8 に縮小
                // 記録サマリー（左詰め統一デザイン）
                VStack(alignment: .leading, spacing: 6) { // 10 -> 6 に縮小
                    // Rep数
                    HStack {
                        Image(systemName: "arrow.up.arrow.down.circle.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text("\(workoutManager.lastSessionRepCount) Reps")
                            .font(.system(.headline, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    // 1RM 表示
                    if workoutManager.lastSessionRepCount > 0 {
                        let w = workoutManager.selectedWeight
                        let rm = Double(w) * (1.0 + 0.0333 * Double(workoutManager.lastSessionRepCount))
                        let rmInt = Int(round(rm))
                        
                        HStack {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("1RM: \(rmInt) kg")
                                .font(.system(.headline, design: .rounded))
                                .foregroundColor(.white)
                        }
                    }
                    
                    // 所要時間
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        Text(formatDuration(workoutManager.lastSessionDuration))
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12) // 少し詰める
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // SAVE ボタン
                Button(action: {
                    HapticManager.playGoalReached() // 保存完了の表現としてSuccess振動
                    workoutManager.saveAndReturn()
                }) {
                    Text("SAVE")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8) // 12 -> 8 に縮小
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // 破棄ボタン
                Button(action: {
                    HapticManager.playClick()
                    workoutManager.returnToHome()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Discard")
                    }
                    .font(.system(.footnote, design: .rounded))
                    .fontWeight(.medium)
                    .foregroundColor(.red.opacity(0.8))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6) // 8 -> 6 に縮小
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
        }
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    ResultView()
        .environmentObject(WorkoutManager())
}
