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
        Form {
            Section {
                // 重量選択（ドロップダウンメニュー形式）
                Picker("Weight", selection: $workoutManager.selectedWeight) {
                    ForEach(Array(stride(from: 20, through: 150, by: 5)), id: \.self) { weight in
                        Text("\(weight) kg").tag(weight)
                    }
                }
                .pickerStyle(.navigationLink)
                
                // 目標回数選択
                Picker("Target Reps", selection: $workoutManager.selectedTargetReps) {
                    ForEach(Array(1...30), id: \.self) { rep in
                        Text("\(rep) reps").tag(rep)
                    }
                }
                .pickerStyle(.navigationLink)
            }
            
            // ワークアウト開始ボタン
            Section {
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
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle("Setup")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WeightSelectionView()
        .environmentObject(WorkoutManager())
}
