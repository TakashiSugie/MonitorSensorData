//
//  HistoryView.swift
//  RepCount Watch App
//
//  過去のワークアウト履歴を表示する画面
//

import SwiftUI

struct HistoryView: View {
    @State private var sessions: [WorkoutSession] = []
    
    var body: some View {
        Group {
            if sessions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                    Text("No History")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    ForEach(sessions) { session in
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
                            
                            // 3段目: バッジ類 (1RM & Avg VBT)
                            HStack(spacing: 6) {
                                if let rm = session.estimated1RM {
                                    HStack(spacing: 4) {
                                        Image(systemName: "flame.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 10))
                                        Text("1RM: \(rm) kg")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.2))
                                    .cornerRadius(4)
                                }
                                
                                if session.velocities.count > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "speedometer")
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 10))
                                        Text(String(format: "Avg: %.2f m/s", session.averageVelocity))
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.cyan.opacity(0.2))
                                    .cornerRadius(4)
                                }
                            }
                        }
                        .padding(.vertical, 4)
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
    
    // MARK: - Helper Methods
    
    private func loadData() {
        sessions = SessionStore.loadSessions()
    }
    
    private func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            SessionStore.deleteSession(id: session.id)
        }
        sessions.remove(atOffsets: offsets)
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
