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
                // 記録サマリー（左詰め統一デザイン）
                VStack(alignment: .leading, spacing: 10) {
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
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
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
