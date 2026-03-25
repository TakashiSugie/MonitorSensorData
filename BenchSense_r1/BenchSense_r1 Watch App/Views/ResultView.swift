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
            VStack(spacing: 12) {
                // エクササイズ名
                Text("Bench Press")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.gray)
                
                // Rep 数
                VStack(spacing: 2) {
                    Text("\(workoutManager.lastSessionRepCount)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    Text("reps")
                        .font(.system(.body, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                // 1RM 表示
                if workoutManager.lastSessionRepCount > 0 {
                    let w = workoutManager.selectedWeight
                    let rm = Double(w) * (1.0 + 0.0333 * Double(workoutManager.lastSessionRepCount))
                    let rmInt = Int(round(rm))
                    
                    Text("Estimated 1RM: \(rmInt) kg")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundColor(.cyan)
                        .padding(.top, 4)
                }
                
                // 所要時間
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.orange)
                    Text(formatDuration(workoutManager.lastSessionDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.top, 4)
                
                // SAVE ボタン
                Button(action: {
                    workoutManager.saveAndReturn()
                }) {
                    Text("SAVE")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                
                // 破棄ボタン
                Button(action: {
                    workoutManager.returnToHome()
                }) {
                    Text("Discard")
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.red.opacity(0.8))
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
