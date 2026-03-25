//
//  SettingsView.swift
//  RepCount Watch App
//
//  ユーザー設定画面（VBTゾーン等のカスタマイズ）
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // Core Settings (Legacy from HomeView)
    @AppStorage("appLanguage") private var appLanguage = "ja"
    @AppStorage("isMuted") private var isMuted = false
    @AppStorage("isLeftArm") private var isLeftArm = true
    @AppStorage("peakThreshold") private var peakThreshold: Double = 0.12
    
    // VBT Target Zone setting
    @AppStorage("vbtTargetZone") private var targetZoneString: String = VBTZone.hypertrophy.rawValue
    
    let thresholdOptions: [Double] = [
        0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09,
        0.10, 0.12, 0.14, 0.16, 0.18, 0.20, 0.25, 0.30
    ]
    
    // Selected Zone as Enum
    private var selectedZone: VBTZone {
        get { VBTZone(rawValue: targetZoneString) ?? .hypertrophy }
        set { targetZoneString = newValue.rawValue }
    }
    
    var body: some View {
        Form {
            // --- Premium Section ---
            Section(header: Text("Premium Features")) {
                if subscriptionManager.isPremium {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VBT Target Zone")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Picker("Objective", selection: $targetZoneString) {
                            ForEach(VBTZone.allCases) { zone in
                                VStack(alignment: .leading) {
                                    Text(zone.rawValue).font(.system(size: 14))
                                    Text(zone.description).font(.system(size: 10)).foregroundColor(.gray)
                                }.tag(zone.rawValue)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .padding(.vertical, 4)
                    
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.yellow)
                            Text("VBT Target Zone")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Standard Plan (\u{00A5}500/mo) unlocks targeted velocity zones for hypertrophy, power, and max strength.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // --- Common Settings Section ---
            Section(header: Text(appLanguage == "ja" ? "アプリ設定" : "App Settings")) {
                // 言語
                Picker(appLanguage == "ja" ? "言語" : "Language", selection: $appLanguage) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }
                
                // サウンド
                Toggle(appLanguage == "ja" ? "音声ミュート" : "Mute Voice", isOn: $isMuted)
                    .tint(.orange)
                
                // 腕
                Picker(appLanguage == "ja" ? "着用する腕" : "Worn On", selection: $isLeftArm) {
                    Text(appLanguage == "ja" ? "左腕" : "Left Arm").tag(true)
                    Text(appLanguage == "ja" ? "右腕" : "Right Arm").tag(false)
                }
            }
            
            // 検出感度
            Section(
                header: Text(appLanguage == "ja" ? "検出感度 (Threshold)" : "Detection Sensitivity"),
                footer: Text(appLanguage == "ja" ? "取りこぼしが多い場合は値を下げてください" : "Lower value if reps are missed")
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
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
}
