//
//  SensorLoggerView.swift
//  BenchCoach Watch App
//
//  センサーデータロガーの操作UI
//

import SwiftUI

struct SensorLoggerView: View {
    @StateObject private var logger = SensorLogger()

    private var elapsedFormatted: String {
        let t = Int(logger.elapsedSeconds)
        return String(format: "%02d:%02d", t / 60, t % 60)
    }

    var body: some View {
        VStack(spacing: 10) {

            // ─── ステータス表示 ───
            VStack(spacing: 4) {
                HStack {
                    Circle()
                        .fill(logger.isLogging ? Color.red : Color.gray.opacity(0.4))
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle()
                                .stroke(logger.isLogging ? Color.red.opacity(0.3) : Color.clear, lineWidth: 3)
                                .scaleEffect(logger.isLogging ? 1.6 : 1.0)
                                .animation(
                                    logger.isLogging
                                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                                        : .default,
                                    value: logger.isLogging
                                )
                        )
                    Text(logger.isLogging ? "REC" : "STANDBY")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(logger.isLogging ? .red : .gray)
                }

                if logger.isLogging {
                    Text(elapsedFormatted)
                        .font(.system(size: 22, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)

                    Text("\(logger.sampleCount) samples")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // ─── ファイル名表示 ───
            if !logger.lastFilename.isEmpty {
                Text(logger.lastFilename)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            // ─── START / STOP ボタン ───
            if logger.isLogging {
                Button(action: { logger.stopLogging() }) {
                    Label("STOP", systemImage: "stop.fill")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.red)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: { logger.startLogging() }) {
                    Label("START", systemImage: "record.circle")
                        .font(.system(.body, design: .rounded).bold())
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
        .navigationTitle("センサーログ")
    }
}

#Preview {
    SensorLoggerView()
}
