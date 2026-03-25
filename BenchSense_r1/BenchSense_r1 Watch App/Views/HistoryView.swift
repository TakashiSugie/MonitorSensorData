//
//  HistoryView.swift
//  BenchSense_r1 Watch App
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formatDate(session.date))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            HStack {
                                Text("\(session.repCount) Reps")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                if let weight = session.weight {
                                    Text("@ \(weight) kg")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Text(formatDuration(session.duration))
                                    .font(.subheadline)
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
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
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
