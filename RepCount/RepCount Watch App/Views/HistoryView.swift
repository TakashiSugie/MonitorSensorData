//
//  HistoryView.swift
//  RepCount Watch App
//
//  過去のワークアウト履歴を表示する画面
//

import SwiftUI

struct HistoryView: View {
    @State private var allSessions: [WorkoutSession] = []
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.openURL) private var openURL
    @State private var showingQRCode = false

    // Premiumかどうかに応じて表示するセッションを絞り込む
    var visibleSessions: [WorkoutSession] {
        if subscriptionManager.isPremium {
            return allSessions
        } else {
            return Array(allSessions.prefix(3))
        }
    }

    var body: some View {
        Group {
            if visibleSessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No History")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    // Premium Unlock Banner for Free Users
                    if !subscriptionManager.isPremium {
                        Section {
                            VStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.yellow)
                                Text("Unlock Unlimited History")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Standard Plan (\u{00A5}500/mo)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .listRowBackground(Color.blue.opacity(0.2))
                        }
                    }

                    // Premium Dashboard Link
                    if subscriptionManager.isPremium {
                        dashboardSection
                    }

                    ForEach(visibleSessions) { session in
                        sessionRow(session: session)
                    }
                    .onDelete(perform: deleteSession)
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadData()
        }
    }

    // MARK: - Subviews

    private var dashboardSection: some View {
        Section {
            let base = workoutManager.sensorStreamer.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let urlString = "\(base)?user=\(workoutManager.sensorStreamer.userID)"

            HStack(spacing: 8) {
                // 1. 直接リンク（システム連携）
                Button(action: {
                    if let url = URL(string: urlString) {
                        print("[HistoryView] Attempting to open personal URL (openURL): \(urlString)")
                        openURL(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("Open Link")
                    }
                }
                .buttonStyle(.bordered)
                .tint(.cyan)

                // 2. QRコード表示 (確実な手段)
                Button(action: {
                    showingQRCode = true
                }) {
                    Image(systemName: "qrcode")
                }
                .buttonStyle(.bordered)
                .tint(.white)
                .frame(width: 44)
            }
            .padding(.vertical, 4)
            .sheet(isPresented: $showingQRCode) {
                QRCodeView(url: urlString)
            }
        }
    }

    private func sessionRow(session: WorkoutSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // 1段目: 日付 & 経過時間
            HStack {
                Text(formatDate(session.date))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)

                Spacer()

                HStack(spacing: 2) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 10))
                    Text(formatDuration(session.duration))
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                }
            }

            // 2段目: 重量 × 回数
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text("\(session.weight ?? 0)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("kg")
                    .font(.caption2)
                    .foregroundColor(.gray)

                Text("×")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 2)

                Text("\(session.repCount)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.orange)
                Text("Reps")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }

            HStack(spacing: 6) {
                if let rm = session.estimated1RM {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 9))
                        Text("1RM: \(rm) kg")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
                }

                if session.velocities.count > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "speedometer")
                            .foregroundColor(.orange)
                            .font(.system(size: 9))
                        Text(String(format: "VEL: %.2f m/s", session.averageVelocity))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Helper Methods

    private func loadData() {
        allSessions = SessionStore.loadSessions()
    }

    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let sessionToDelete = visibleSessions[index]
            if let realIndex = allSessions.firstIndex(where: { $0.id == sessionToDelete.id }) {
                let session = allSessions[realIndex]
                SessionStore.deleteSession(id: session.id)
                allSessions.remove(at: realIndex)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

#Preview {
    HistoryView()
}
