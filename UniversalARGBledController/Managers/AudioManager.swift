//
//  AudioManager.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import Foundation
import AVFoundation
import AudioToolbox
import SwiftUI
import Accelerate
import CoreAudio

@MainActor
class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var musicSyncEnabled = false
    @Published var currentBeat: Float = 0.0
    @Published var bassLevel: Float = 0.0
    @Published var midLevel: Float = 0.0
    @Published var trebleLevel: Float = 0.0
    @Published var bpm: Float = 0.0
    @Published var overallVolume: Float = 0.0
    @Published var audioLevel: Float = 0.0
    @Published var dominantFrequency: Float = 0.0
    
    // MARK: - Audio Properties
    private var audioEngine: AVAudioEngine!
    private var mixer: AVAudioMixerNode!
    private var playerNode: AVAudioPlayerNode!
    private var audioFormat: AVAudioFormat!
    private var fftSetup: FFTSetup!
    private var bufferSize = 1024
    private var sampleRate: Double = 44100
    
    // MARK: - Analysis Properties
    private var fftBuffer: [Float] = []
    private var window: [Float] = []
    private var magnitudes: [Float] = []
    private var beatHistory: [Float] = []
    private var lastBeatTime: TimeInterval = 0
    
    // MARK: - Timer for simulation
    private var analysisTimer: Timer?
    
    // MARK: - Dependencies
    weak var ledController: LEDController?
    
    // MARK: - Initialization
    init() {
        setupFFT()
        setupAudioEngine()
    }
    
    deinit {
        if fftSetup != nil {
            vDSP_destroy_fftsetup(fftSetup)
        }
        analysisTimer?.invalidate()
        // audioEngine?.stop() // Geçici olarak kapalı
    }
    
    func requestMicrophonePermission() async -> Bool {
        // Sistem ses çıkışı için özel izin gerekmez
        return true
    }
    
    func setLEDController(_ controller: LEDController) {
        ledController = controller
    }
    
    func startListening() async {
        // Geçici olarak sadece simülasyon
        isRecording = true
        startAnalysisTimer()
        print("🎤 Simülasyon modu başlatıldı")
    }
    
    func stopListening() {
        // audioEngine.stop() // Geçici olarak kapalı
        analysisTimer?.invalidate()
        isRecording = false
        print("🎤 Simülasyon modu durduruldu")
    }
    
    func toggleMusicSync() {
        musicSyncEnabled.toggle()
        
        if musicSyncEnabled {
            Task {
                await startListening()
            }
        } else {
            stopListening()
        }
        
        ledController?.enableMusicSync(musicSyncEnabled)
    }
    
    // MARK: - Private Methods
    private func setupAudioEngine() {
        // Ses sistemi geçici olarak devre dışı
        print("🔇 Ses sistemi geçici olarak devre dışı bırakıldı")
        
        // Sadece timer tabanlı simülasyon
        audioFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
    }
    
    private func setupFFT() {
        let log2n = UInt(log2(Float(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        
        fftBuffer = Array(repeating: 0.0, count: bufferSize)
        window = Array(repeating: 0.0, count: bufferSize)
        magnitudes = Array(repeating: 0.0, count: bufferSize / 2)
        
        // Hanning window oluştur
        vDSP_hann_window(&window, vDSP_Length(bufferSize), 0)
    }
    
    private func startAnalysisTimer() {
        analysisTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.simulateAudioAnalysis()
            }
        }
    }
    
    private func simulateAudioAnalysis() {
        // Gerçek ses analizi yerine simülasyon
        let time = Date().timeIntervalSince1970
        
        // Sinüs dalgalarıyla ses seviyelerini simüle et
        bassLevel = Float(abs(sin(time * 2)) * 0.8)
        midLevel = Float(abs(sin(time * 3)) * 0.6)
        trebleLevel = Float(abs(sin(time * 5)) * 0.4)
        overallVolume = (bassLevel + midLevel + trebleLevel) / 3
        audioLevel = overallVolume
        dominantFrequency = Float(440 + sin(time) * 200) // 240-640 Hz aralığında
        
        // Beat simülasyonu
        let beatInterval = 60.0 / 120.0 // 120 BPM
        if time - lastBeatTime > beatInterval {
            currentBeat = 1.0
            lastBeatTime = time
        } else {
            currentBeat = max(0, currentBeat - 0.1)
        }
        
        bpm = 120.0
        
        // LED kontrolcüsüne gönder
        updateLEDsWithMusicData()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let frameLength = Int(buffer.frameLength)
        let audioData = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        
        if audioData.count >= bufferSize {
            analyzeAudioData(Array(audioData.prefix(bufferSize)))
        }
    }
    
    private func analyzeAudioData(_ audioData: [Float]) {
        // Window uygula
        var windowedData = [Float](repeating: 0, count: bufferSize)
        vDSP_vmul(audioData, 1, window, 1, &windowedData, 1, vDSP_Length(bufferSize))
        
        // FFT uygula
        performFFT(windowedData)
        
        // Frekans bandlarını analiz et
        analyzeFuencyBands()
        
        // Beat detection
        detectBeat()
        
        // LED güncellemesi
        updateLEDsWithMusicData()
    }
    
    private func performFFT(_ data: [Float]) {
        var realPart = [Float](repeating: 0, count: bufferSize / 2)
        var imagPart = [Float](repeating: 0, count: bufferSize / 2)
        
        // Real ve imaginary kısımları ayır
        for i in 0..<bufferSize / 2 {
            realPart[i] = data[i * 2]
            imagPart[i] = i * 2 + 1 < data.count ? data[i * 2 + 1] : 0
        }
        
        realPart.withUnsafeMutableBufferPointer { realPtr in
            imagPart.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                let log2n = UInt(log2(Float(bufferSize)))
                vDSP_fft_zrip(fftSetup!, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Magnitude hesapla
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(bufferSize / 2))
            }
        }
    }
    
    private func analyzeFuencyBands() {
        let bandSize = magnitudes.count / 3
        
        // Bass (20-250 Hz)
        let bassRange = 0..<bandSize
        bassLevel = sqrt(magnitudes[bassRange].reduce(0, +) / Float(bandSize))
        
        // Mid (250-4000 Hz)
        let midRange = bandSize..<(bandSize * 2)
        midLevel = sqrt(magnitudes[midRange].reduce(0, +) / Float(bandSize))
        
        // Treble (4000+ Hz)
        let trebleRange = (bandSize * 2)..<magnitudes.count
        trebleLevel = sqrt(magnitudes[trebleRange].reduce(0, +) / Float(trebleRange.count))
        
        // Genel seviye
        overallVolume = (bassLevel + midLevel + trebleLevel) / 3
        audioLevel = overallVolume
        
        // Baskın frekans hesapla
        if let maxIndex = magnitudes.enumerated().max(by: { $0.element < $1.element })?.offset {
            dominantFrequency = Float(maxIndex) * Float(sampleRate) / Float(bufferSize)
        }
    }
    
    private func detectBeat() {
        let energy = bassLevel + midLevel * 0.5
        beatHistory.append(energy)
        
        if beatHistory.count > 43 { // ~1 saniye @ 43fps
            beatHistory.removeFirst()
        }
        
        let averageEnergy = beatHistory.reduce(0, +) / Float(beatHistory.count)
        let variance = beatHistory.map { pow($0 - averageEnergy, 2) }.reduce(0, +) / Float(beatHistory.count)
        let threshold = averageEnergy + sqrt(variance) * 1.5
        
        let currentTime = Date().timeIntervalSince1970
        
        if energy > threshold && currentTime - lastBeatTime > 0.3 {
            currentBeat = 1.0
            lastBeatTime = currentTime
            
            // BPM hesapla
            if beatHistory.count > 10 {
                let timeDiff = currentTime - lastBeatTime
                bpm = Float(60.0 / timeDiff)
                bpm = max(60, min(180, bpm)) // Makul BPM aralığı
            }
        } else {
            currentBeat = max(0, currentBeat - 0.05)
        }
    }
    
    private func updateLEDsWithMusicData() {
        guard musicSyncEnabled, let ledController = ledController else { return }
        
        // Renk hesapla
        let beatColor = colorFromBeat()
        
        // Beat strength'e göre parlaklık
        let brightness = Double(overallVolume.clamped(to: 0.1...1.0))
        
        // Speed bass'a göre ayarla
        let speed = Double(bassLevel * 100).clamped(to: 10...100)
        
        // LED controller'a gönder
        Task { @MainActor in
            ledController.updateMusicSync(
                color: beatColor,
                brightness: brightness,
                speed: speed,
                bassLevel: Int(bassLevel * 255),
                midLevel: Int(midLevel * 255),
                trebleLevel: Int(trebleLevel * 255),
                bpm: Int(bpm)
            )
        }
    }
    
    private func colorFromBeat() -> Color {
        // Frekans bandlarına göre renk karışımı
        let red = Double(bassLevel.clamped(to: 0...1))
        let green = Double(midLevel.clamped(to: 0...1))
        let blue = Double(trebleLevel.clamped(to: 0...1))
        
        return Color(red: red, green: green, blue: blue)
    }
}

// MARK: - Extensions
extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}