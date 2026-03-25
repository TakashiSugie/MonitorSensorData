//
//  HomeView.swift
//  RepCount Watch App
//
//  ホーム画面 - START ボタン
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                Spacer()
                
                // アイコン
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 36))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.orange, .red],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                
                // タイトル
                Text("Bench Press")
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // START ボタン (遷移リンク)
                NavigationLink(destination: WeightSelectionView()) {
                    Text("START")
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
                .simultaneousGesture(TapGesture().onEnded {
                    HapticManager.playClick()
                })
                
                // 履歴 & 設定ボタン（アイコンのみ）
                HStack(spacing: 8) {
                    NavigationLink(destination: HistoryView()) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: SettingsView()) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 4)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("isMuted") private var isMuted = false
    @AppStorage("isLeftArm") private var isLeftArm = true
    
    var body: some View {
        Form {
            Section(header: Text("Sound")) {
                Toggle("Mute Voice", isOn: $isMuted)
                    .tint(.mint)
            }
            
            Section(header: Text("Worn On")) {
                Picker("Arm", selection: $isLeftArm) {
                    Text("Left Arm").tag(true)
                    Text("Right Arm").tag(false)
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
        .environmentObject(WorkoutManager())
}
