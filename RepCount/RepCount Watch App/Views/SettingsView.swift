//
//  SettingsView.swift
//  BenchCoach Watch App
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
            // --- Common Settings Section ---
            Section(header: Text(appLanguage == "ja" ? "一般設定" : "General Settings")) {
                // 言語
                Picker(appLanguage == "ja" ? "言語" : "Language", selection: $appLanguage) {
                    Text("日本語").tag("ja")
                    Text("English").tag("en")
                }

                // サウンド
                Picker(appLanguage == "ja" ? "サウンド" : "Sound", selection: $isMuted) {
                    Text(appLanguage == "ja" ? "ON" : "ON").tag(false)
                    Text(appLanguage == "ja" ? "ミュート" : "Mute").tag(true)
                }

                // 腕
                Picker(appLanguage == "ja" ? "着用する腕" : "Worn On", selection: $isLeftArm) {
                    Text(appLanguage == "ja" ? "左腕" : "Left Arm").tag(true)
                    Text(appLanguage == "ja" ? "右腕" : "Right Arm").tag(false)
                }

                // 検出の閾値
                Picker(appLanguage == "ja" ? "検出の閾値" : "Threshold", selection: $peakThreshold) {
                    ForEach(thresholdOptions, id: \.self) { val in
                        if val == 0.12 {
                            Text(String(format: appLanguage == "ja" ? "%.2f (推奨)" : "%.2f (Default)", val)).tag(val)
                        } else {
                            Text(String(format: "%.2f", val)).tag(val)
                        }
                    }
                }
            }

            // --- Premium Section (Moved to Bottom) ---
            Section(header: Text(appLanguage == "ja" ? "速度の理想範囲設定" : "Lifting Velocity Target")) {
                if subscriptionManager.isPremium {
                    Picker("", selection: $targetZoneString) {
                        ForEach(VBTZone.allCases) { zone in
                            VStack(alignment: .leading) {
                                Text(zone.rawValue).font(.system(size: 14))
                                Text(zone.description).font(.system(size: 10)).foregroundColor(.gray)
                            }.tag(zone.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "lock.fill").foregroundColor(.yellow)
                            Text(appLanguage == "ja" ? "プレミアム機能" : "Premium Features")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Standard Plan (\u{00A5}500/mo) unlocks targeted velocity zones.")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 2)
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
