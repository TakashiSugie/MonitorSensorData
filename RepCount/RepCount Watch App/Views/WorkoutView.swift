//
//  WorkoutView.swift
//  BenchCoach Watch App
//
//  トレーニング画面 - カウンター & 操作ボタン
//

import SwiftUI

struct WorkoutView: View {
    @EnvironmentObject var workoutManager: WorkoutManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    
    @AppStorage("vbtTargetZone") private var targetZoneString: String = VBTZone.hypertrophy.rawValue
    
    private var selectedZone: VBTZone {
        VBTZone(rawValue: targetZoneString) ?? .hypertrophy
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 経過時間 (右上)
            HStack {
                Spacer()
                Text(formatTime(workoutManager.elapsedTime))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
            .padding(.top, 2)
            
            Spacer(minLength: 0)
            
            // トレーニング情報 (左揃え)
            VStack(alignment: .leading, spacing: 8) {
                // Rep表示
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(workoutManager.repCount)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: workoutManager.repCount)
                    
                    Text("Rep")
                        .font(.system(.headline, design: .rounded))
                        .foregroundColor(.gray)
                }
                
                // Lifting Velocity (挙上速度)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.2f", workoutManager.lastRepVelocity))
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor({
                                if subscriptionManager.isPremium && workoutManager.lastRepVelocity > 0 {
                                    return selectedZone.range.contains(workoutManager.lastRepVelocity) ? .green : .white
                                }
                                return .white
                            }())
                        
                        Text("m/s")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.gray)
                    }
                    
                    if subscriptionManager.isPremium {
                        Text("\(selectedZone.rawValue) (\(selectedZone.description))")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 12)
            
            Spacer(minLength: 0)
            
            // 操作ボタン
            HStack(spacing: 8) {
                // -1 ボタン
                Button(action: {
                    HapticManager.playClick()
                    workoutManager.decrementRep()
                }) {
                    Image(systemName: "minus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                
                // STOP ボタン
                Button(action: {
                    HapticManager.playClick()
                    workoutManager.stopWorkout()
                }) {
                    Text("STOP")
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
                // +1 ボタン
                Button(action: {
                    HapticManager.playClick()
                    workoutManager.incrementRep()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.gray.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 4)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    WorkoutView()
        .environmentObject(WorkoutManager())
}
