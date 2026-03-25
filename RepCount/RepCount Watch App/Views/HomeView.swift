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
    @AppStorage("appLanguage") private var appLanguage = "ja"
    @AppStorage("isMuted") private var isMuted = false
    @AppStorage("isLeftArm") private var isLeftArm = true
    @AppStorage("peakThreshold") private var peakThreshold: Double = 0.12
    
    let thresholdOptions: [Double] = [
        0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09,
        0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.25, 0.30
    ]
    
    var body: some View {
        Form {
            Section(header: Text(appLanguage == "ja" ? "言語 / Language" : "Language")) {
                Picker("", selection: $appLanguage) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            
            Section(header: Text(appLanguage == "ja" ? "サウンド" : "Sound")) {
                Toggle(appLanguage == "ja" ? "音声ミュート" : "Mute Voice", isOn: $isMuted)
                    .tint(.mint)
            }
            
            Section(header: Text(appLanguage == "ja" ? "着用する腕" : "Worn On")) {
                Picker("", selection: $isLeftArm) {
                    Text(appLanguage == "ja" ? "左腕" : "Left Arm").tag(true)
                    Text(appLanguage == "ja" ? "右腕" : "Right Arm").tag(false)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            
            Section(
                header: Text(appLanguage == "ja" ? "検出感度 (Threshold)" : "Detection Sensitivity"),
                footer: Text(appLanguage == "ja" ? "取りこぼしが多い場合はスワイプして値を下げてください" : "Lower the value if reps are missed")
            ) {
                Picker("Threshold", selection: $peakThreshold) {
                    ForEach(thresholdOptions, id: \.self) { val in
                        if val == 0.12 {
                            Text(String(format: appLanguage == "ja" ? "%.2f (推奨)" : "%.2f (Default)", val)).tag(val)
                        } else {
                            Text(String(format: "%.2f", val)).tag(val)
                        }
                    }
                }
            }
        }
        .navigationTitle(appLanguage == "ja" ? "設定" : "Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    HomeView()
        .environmentObject(WorkoutManager())
}
