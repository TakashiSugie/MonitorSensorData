//
//  SettingsView.swift
//  RepCount Watch App
//
//  ユーザー設定画面（VBTゾーン等のカスタマイズ）
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    // VBT Target Zone setting stored in UserDefaults
    @AppStorage("vbtTargetZone") private var targetZoneString: String = VBTZone.hypertrophy.rawValue
    
    // Selected Zone as Enum Enum
    var selectedZone: VBTZone {
        get { VBTZone(rawValue: targetZoneString) ?? .hypertrophy }
        set { targetZoneString = newValue.rawValue }
    }
    
    var body: some View {
        List {
            Section(header: Text("Premium Features")) {
                if subscriptionManager.isPremium {
                    // Premium User Area
                    VStack(alignment: .leading, spacing: 8) {
                        Text("VBT Target Zone")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.orange)
                        
                        Picker("Objective", selection: Binding(
                            get: { self.selectedZone },
                            set: { self.selectedZone = $0 }
                        )) {
                            ForEach(VBTZone.allCases) { zone in
                                VStack(alignment: .leading) {
                                    Text(zone.rawValue).font(.system(size: 14))
                                    Text(zone.description).font(.system(size: 10)).foregroundColor(.gray)
                                }.tag(zone)
                            }
                        }
                        .pickerStyle(NavigationLinkPickerStyle())
                    }
                    .padding(.vertical, 4)
                    
                } else {
                    // Free User Area
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.yellow)
                            Text("VBT Target Zone")
                                .font(.system(size: 14, weight: .bold))
                            Spacer()
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
        }
        .navigationTitle("Settings")
    }
}

#Preview {
    SettingsView()
        .environmentObject(SubscriptionManager())
}
