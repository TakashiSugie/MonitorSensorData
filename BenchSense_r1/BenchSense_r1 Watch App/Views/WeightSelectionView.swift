//
//  WeightSelectionView.swift
//  BenchSense_r1 Watch App
//
//  STARTボタン押下後の重量選択画面
//

import SwiftUI

struct WeightSelectionView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            // 重量選択（ドロップダウンメニュー形式）
            Picker("Weight", selection: $workoutManager.selectedWeight) {
                ForEach(Array(stride(from: 20, through: 150, by: 5)), id: \.self) { weight in
                    Text("\(weight) kg").tag(weight)
                }
            }
            .pickerStyle(.navigationLink) // WatchOSのドロップダウン風スタイル
            
            Spacer()
            
            // ワークアウト開始ボタン
            Button(action: {
                workoutManager.startWorkout()
            }) {
                Text("GO")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
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
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WeightSelectionView()
        .environmentObject(WorkoutManager())
}
