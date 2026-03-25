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
        List {
            // 重量選択（ドロップダウンメニュー形式）
            Picker("Weight", selection: $workoutManager.selectedWeight) {
                ForEach(Array(stride(from: 20, through: 150, by: 5)), id: \.self) { weight in
                    Text("\(weight) kg")
                        .font(.system(.body, design: .rounded))
                        .tag(weight)
                }
            }
            .pickerStyle(.navigationLink)
            
            // 目標回数選択
            Picker("Target Reps", selection: $workoutManager.selectedTargetReps) {
                ForEach(Array(1...30), id: \.self) { rep in
                    Text("\(rep) reps")
                        .font(.system(.body, design: .rounded))
                        .tag(rep)
                }
            }
            .pickerStyle(.navigationLink)
            
            // ワークアウト開始ボタン
            Button(action: {
                HapticManager.playClick()
                workoutManager.startWorkout()
            }) {
                Text("GO")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .padding(.top, 4)
        }
        .environment(\.defaultMinListRowHeight, 40) // 各行の幅(高さ)を圧縮
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WeightSelectionView()
        .environmentObject(WorkoutManager())
}
