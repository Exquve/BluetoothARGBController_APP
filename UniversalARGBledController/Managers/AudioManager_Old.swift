//
//  AudioManager.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import Foundation
import AVFoundation
import CoreAudio
import AudioToolbox
import Combine
import Accelerate
import SwiftUI

class AudioManager: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var audioLevel: Double = 0.0
    @Published var bassLevel: Double = 0.0
    @Published var midLevel: Double = 0.0
    @Published var trebleLevel: Double = 0.0
    @Published var dominantFrequency: Double = 0.0
    @Published var bpm: Double = 0.0
    @Published var musicSyncEnabled = false
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioFormat: AVAudioFormat!
    private var fftSetup: FFTSetup?
    private var audioBuffer: [Float] = []
    private let bufferSize = 1024
    private let sampleRate: Double = 44100.0
    
    // Beat detection properties
    private var beatHistory: [Double] = []
    private var lastBeatTime: TimeInterval = 0
    private var energyHistory: [Double] = []
    
    // Frequency analysis
    private var frequencyBands: [Double] = []
    private let bassRange = 20.0...250.0      // Hz
    private let midRange = 250.0...4000.0     // Hz  
    private let trebleRange = 4000.0...20000.0 // Hz
    
    // LED Controller reference
    private var ledController: LEDController?
    
    init() {
        setupAudioEngine()
        setupFFT()
    }
    
    deinit {
        if let fftSetup = fftSetup {
            vDSP_destroy_fftsetup(fftSetup)
        }
    }
    
    // MARK: - Public Methods
    func setLEDController(_ controller: LEDController) {
        self.ledController = controller
    }
    
    func requestMicrophonePermission() async -> Bool {
        // macOS doesn't need explicit permission request like iOS
        // The system will prompt automatically when audio input is accessed
        return true
    }
    
    func startListening() async {
        guard await requestMicrophonePermission() else {
            print("🎤 Mikrofon izni reddedildi")
            return
        }
        
        do {
            try audioEngine.start()
            isRecording = true
            print("🎤 Ses analizi başlatıldı")
        } catch {
            print("❌ Ses engine başlatma hatası: \(error)")
        }
    }
    
    func stopListening() {
        audioEngine.stop()
        isRecording = false
        print("🎤 Ses analizi durduruldu")
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
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        
        // Input node'un mevcut formatını kullanalım
        audioFormat = inputNode.outputFormat(forBus: 0)
        
        // Mikrofon formatıyla uyumlu olacak şekilde ayarlayalım
        let recordingFormat = audioFormat
        
        inputNode.installTap(onBus: 0, bufferSize: UInt32(bufferSize), format: recordingFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }
    }
    
    private func setupFFT() {
        let log2n = UInt(log2(Double(bufferSize)))
        fftSetup = vDSP_create_fftsetup(log2n, Int32(kFFTRadix2))
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0],
              let fftSetup = fftSetup else { return }
        
        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData, count: frameCount))
        
        // RMS (Root Mean Square) hesapla - genel ses seviyesi
        let rms = calculateRMS(samples)
        
        DispatchQueue.main.async {
            self.audioLevel = Double(rms)
        }
        
        // FFT analizi yap
        performFFTAnalysis(samples: samples, fftSetup: fftSetup)
        
        // Beat detection
        detectBeat(energyLevel: Double(rms))
    }
    
    private func calculateRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, UInt(samples.count))
        return rms
    }
    
    private func performFFTAnalysis(samples: [Float], fftSetup: FFTSetup) {
        let log2n = UInt(log2(Double(bufferSize)))
        let n = Int(pow(2.0, Double(log2n)))
        
        // Pad or trim samples to exact buffer size
        var paddedSamples = samples
        if paddedSamples.count < n {
            paddedSamples.append(contentsOf: Array(repeating: 0.0, count: n - paddedSamples.count))
        } else if paddedSamples.count > n {
            paddedSamples = Array(paddedSamples.prefix(n))
        }
        
        // Prepare FFT input
        var realp = [Float](paddedSamples[0..<n/2])
        var imagp = [Float](repeating: 0.0, count: n/2)
        
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                // Perform FFT
                vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitude spectrum
                var magnitudes = [Float](repeating: 0.0, count: n/2)
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, UInt(n/2))
                
                // Analyze frequency bands
                self.analyzeFrequencyBands(magnitudes: magnitudes)
            }
        }
    }
    
    private func analyzeFrequencyBands(magnitudes: [Float]) {
        let nyquistFreq = sampleRate / 2.0
        let freqResolution = nyquistFreq / Double(magnitudes.count)
        
        var bassEnergy: Double = 0
        var midEnergy: Double = 0
        var trebleEnergy: Double = 0
        var maxMagnitude: Float = 0
        var dominantBin = 0
        
        for (bin, magnitude) in magnitudes.enumerated() {
            let frequency = Double(bin) * freqResolution
            let energy = Double(magnitude)
            
            // Find dominant frequency
            if magnitude > maxMagnitude {
                maxMagnitude = magnitude
                dominantBin = bin
            }
            
            // Categorize by frequency ranges
            if bassRange.contains(frequency) {
                bassEnergy += energy
            } else if midRange.contains(frequency) {
                midEnergy += energy
            } else if trebleRange.contains(frequency) {
                trebleEnergy += energy
            }
        }
        
        let totalEnergy = bassEnergy + midEnergy + trebleEnergy
        
        DispatchQueue.main.async {
            // Normalize energy levels
            if totalEnergy > 0 {
                self.bassLevel = bassEnergy / totalEnergy
                self.midLevel = midEnergy / totalEnergy
                self.trebleLevel = trebleEnergy / totalEnergy
            }
            
            // Calculate dominant frequency
            self.dominantFrequency = Double(dominantBin) * freqResolution
            
            // Send data to LED controller if music sync is enabled
            if self.musicSyncEnabled {
                self.ledController?.updateWithMusicData(
                    bassLevel: self.bassLevel,
                    midLevel: self.midLevel, 
                    trebleLevel: self.trebleLevel,
                    dominantFrequency: self.dominantFrequency
                )
            }
        }
    }
    
    private func detectBeat(energyLevel: Double) {
        let currentTime = Date().timeIntervalSince1970
        
        // Add to energy history
        energyHistory.append(energyLevel)
        if energyHistory.count > 43 { // Approximately 1 second of history at ~43Hz
            energyHistory.removeFirst()
        }
        
        // Calculate average energy over history
        let avgEnergy = energyHistory.reduce(0, +) / Double(energyHistory.count)
        let variance = energyHistory.map { pow($0 - avgEnergy, 2) }.reduce(0, +) / Double(energyHistory.count)
        let threshold = avgEnergy + sqrt(variance) * 1.5
        
        // Detect beat
        if energyLevel > threshold && (currentTime - lastBeatTime) > 0.3 { // Minimum 300ms between beats
            lastBeatTime = currentTime
            
            // Add to beat history for BPM calculation
            beatHistory.append(currentTime)
            if beatHistory.count > 8 { // Keep last 8 beats
                beatHistory.removeFirst()
            }
            
            // Calculate BPM
            if beatHistory.count >= 2 {
                let timeDiff = beatHistory.last! - beatHistory.first!
                let beatsPerSecond = Double(beatHistory.count - 1) / timeDiff
                let calculatedBPM = beatsPerSecond * 60.0
                
                DispatchQueue.main.async {
                    // Smooth BPM changes
                    if abs(calculatedBPM - self.bpm) < 30 || self.bpm == 0 {
                        self.bpm = calculatedBPM
                    }
                }
            }
            
            // Trigger beat response in LED controller
            if musicSyncEnabled {
                triggerBeatResponse()
            }
        }
    }
    
    private func triggerBeatResponse() {
        // Create a beat-synchronized flash effect
        let beatColor = colorFromBeat()
        
        DispatchQueue.main.async {
            // Temporary brightness boost for beat
            self.ledController?.updateWithMusicData(
                bassLevel: min(self.bassLevel * 2.0, 1.0),
                midLevel: self.midLevel,
                trebleLevel: self.trebleLevel,
                dominantFrequency: self.dominantFrequency
            )
        }
    }
    
    private func colorFromBeat() -> (r: Int, g: Int, b: Int) {
        // Generate color based on frequency content
        let bassWeight = bassLevel
        let midWeight = midLevel  
        let trebleWeight = trebleLevel
        
        let red = Int(bassWeight * 255)
        let green = Int(midWeight * 255)
        let blue = Int(trebleWeight * 255)
        
        return (red, green, blue)
    }
    
    // MARK: - Visualization Helper Methods
    func getVisualizationData() -> AudioVisualizationData {
        return AudioVisualizationData(
            level: audioLevel,
            bass: bassLevel,
            mid: midLevel,
            treble: trebleLevel,
            frequency: dominantFrequency,
            bpm: bpm
        )
    }
}

// MARK: - Audio Visualization Data Structure
struct AudioVisualizationData {
    let level: Double
    let bass: Double
    let mid: Double
    let treble: Double
    let frequency: Double
    let bpm: Double
    
    var bassHeight: CGFloat { CGFloat(bass * 100) }
    var midHeight: CGFloat { CGFloat(mid * 100) }
    var trebleHeight: CGFloat { CGFloat(treble * 100) }
    var levelHeight: CGFloat { CGFloat(level * 200) }
    
    var frequencyColor: Color {
        let normalizedFreq = min(max(frequency / 20000.0, 0.0), 1.0)
        return Color(hue: normalizedFreq * 0.8, saturation: 1.0, brightness: 1.0)
    }
}