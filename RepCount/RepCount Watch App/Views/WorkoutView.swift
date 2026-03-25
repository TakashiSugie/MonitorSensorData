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
        VStack(spacing: 2) {
            // 経過時間 (右上)
            HStack {
                Spacer()
                Text(formatTime(workoutManager.elapsedTime))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(.gray)
                    .padding(.trailing, 4)
            }
            .padding(.top, 0)
            
            Spacer(minLength: 0)
            
            // --- トレーニング情報 (2つのエリア) ---
            VStack(spacing: 4) {
                // Area 1: Reps
                RepDisplayView(repCount: workoutManager.repCount)
                
                // Area 2: Velocity
                VelocityDisplayView(
                    lastRepVelocity: workoutManager.lastRepVelocity,
                    isPremium: subscriptionManager.isPremium,
                    selectedZone: selectedZone
                )
            }
            .padding(.horizontal, 4)
            
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
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.3))
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
                        .padding(.vertical, 8)
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
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.3))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 4)
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

// MARK: - Subviews

struct RepDisplayView: View {
    let repCount: Int
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                ZStack(alignment: .trailing) {
                    Text("0000").font(.system(size: 34, weight: .bold, design: .rounded)).opacity(0)
                    Text("\(repCount)")
                        .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(LinearGradient(colors: [.orange, .yellow], startPoint: .top, endPoint: .bottom))
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.3), value: repCount)
                }
                Text("Rep").font(.system(.subheadline, design: .rounded)).foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

struct VelocityDisplayView: View {
    let lastRepVelocity: Double
    let isPremium: Bool
    let selectedZone: VBTZone
    
    var body: some View {
        VStack(spacing: 4) {
            
            if isPremium {
                Text("\(selectedZone.rawValue) (\(selectedZone.description))")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
                    .foregroundColor(.white)
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(format: "%.2f", lastRepVelocity))
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle({
                        if isPremium && lastRepVelocity > 0 {
                            return selectedZone.range.contains(lastRepVelocity) ? 
                                LinearGradient(colors: [.green, .white], startPoint: .top, endPoint: .bottom) :
                                LinearGradient(colors: [.white, .gray], startPoint: .top, endPoint: .bottom)
                        }
                        return LinearGradient(colors: [.white, .white], startPoint: .top, endPoint: .bottom)
                    }())
                
                Text("m/s")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}
