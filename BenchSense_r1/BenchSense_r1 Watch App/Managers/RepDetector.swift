import Foundation

/// ベンチプレスの動作フェーズ
enum RepPhase: String {
    case idle
    case descending
    case bottom
    case ascending
    case lockout
}

class RepDetector {

    // MARK: - Properties
    private(set) var repCount: Int = 0
    private(set) var currentPhase: RepPhase = .idle
    var onRepDetected: (() -> Void)?

    private(set) var velocity: Double = 0.0      // 速度 (m/s)
    private(set) var displacement: Double = 0.0  // 変位 (m)
    private(set) var filteredAccY: Double = 0.0

    // MARK: - Constants
    private let dt: Double = 1.0 / 50.0          // 50Hz
    private let filterAlpha: Double = 0.2

    // 【調整ポイント】ハイパスフィルタ係数を 0.985 に引き上げ
    // これにより、80kg以上のセットで発生する「3〜5秒間の超低速挙上」を
    // 途切れさせることなく追跡できるようになります。
    private let highPassAlpha: Double = 0.985

    // 【調整ポイント】移動距離の閾値を 0.15 (15cm) に設定
    // 速度感度を上げた分、ラックアウト時の揺れなどを拾わないよう
    // 「物理的にしっかり動いたこと」を条件にして精度を担保します。
    private let displacementThreshold: Double = 0.15

    private let velocityThreshold: Double = 0.04   // 動き出し判定

    // MARK: - Public Methods

    func processAcceleration(accX: Double, accY: Double, accZ: Double) {
        // 1. ローパスフィルタ
        filteredAccY = filterAlpha * accY + (1.0 - filterAlpha) * filteredAccY

        // 2. 積分とハイパスフィルタ
        let instantVelocity = velocity + (filteredAccY * 9.81 * dt)
        velocity = instantVelocity * highPassAlpha

        displacement += velocity * dt

        // 3. 状態マシンの更新
        updateStateMachine()
    }

    func reset() {
        repCount = 0
        currentPhase = .idle
        velocity = 0.0
        displacement = 0.0
        filteredAccY = 0.0
    }

    // MARK: - Private Methods

    private func updateStateMachine() {
        switch currentPhase {
        case .idle:
            if velocity < -velocityThreshold {
                currentPhase = .descending
                displacement = 0
            }

        case .descending:
            if velocity > 0 {
                currentPhase = .bottom
                displacement = 0
            }

        case .bottom:
            if velocity > velocityThreshold {
                currentPhase = .ascending
            }
            if velocity < -velocityThreshold {
                currentPhase = .descending
            }

        case .ascending:
            // 低速挙上（粘りの1レップ）を判定
            if velocity < velocityThreshold {
                if displacement > displacementThreshold {
                    currentPhase = .lockout
                } else if displacement < 0.03 {
                    // 距離が足りない場合はノイズとしてリセット
                    currentPhase = .idle
                    velocity = 0
                    displacement = 0
                }
            }
            if velocity < -velocityThreshold {
                currentPhase = .descending
            }

        case .lockout:
            repCount += 1
            onRepDetected?()

            velocity = 0
            displacement = 0
            currentPhase = .idle
        }
    }
}
