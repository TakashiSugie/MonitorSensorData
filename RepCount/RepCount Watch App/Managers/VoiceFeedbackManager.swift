//
//  VoiceFeedbackManager.swift
//  BenchCoach Watch App
//
//  音声合成（読み上げ）とオーディオセッションの管理
//

import Foundation
import AVFoundation

class VoiceFeedbackManager {
    static let shared = VoiceFeedbackManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    private init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("[VoiceFeedbackManager] Failed to setup audio session: \(error)")
        }
    }
    
    func speak(_ text: String) {
        let isMuted = UserDefaults.standard.bool(forKey: "isMuted")
        guard !isMuted else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }
}
