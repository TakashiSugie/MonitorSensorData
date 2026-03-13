#if os(watchOS)
import SwiftUI

/// ホーム画面 - トレーニング開始
struct HomeView: View {
    
    @StateObject private var motionManager = MotionManager()
    @StateObject private var workoutManager = WorkoutManager()
    @State private var isWorkoutActive = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                
                // アプリアイコン
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                
                // タイトル
                Text("Bench Press")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                // STARTボタン
                NavigationLink(destination: WorkoutView(
                    motionManager: motionManager,
                    workoutManager: workoutManager
                )) {
                    Text("START")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            .padding()
        }
        .onAppear {
            workoutManager.requestAuthorization()
        }
    }
}

#Preview {
    HomeView()
}
#endif
