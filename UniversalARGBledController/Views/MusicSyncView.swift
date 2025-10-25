//
//  MusicSyncView.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI

struct MusicSyncView: View {
    @EnvironmentObject var audioManager: AudioManager
    @EnvironmentObject var ledController: LEDController
    @State private var showingPermissionAlert = false
    @State private var selectedVisualizationMode = 0
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                VStack(alignment: .leading) {
                    Text("Müzik Senkronizasyonu")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("LED'leri müzik ritmine göre kontrol edin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Main Toggle
                Toggle("Music Sync", isOn: $audioManager.musicSyncEnabled)
                    .toggleStyle(SwitchToggleStyle())
                    .onChange(of: audioManager.musicSyncEnabled) { _ in
                        audioManager.toggleMusicSync()
                    }
            }
            
            // Status Card
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(audioManager.isRecording ? .green : .red)
                            .frame(width: 12, height: 12)
                        
                        Text(audioManager.isRecording ? "🎵 Dinleniyor" : "⏹️ Durduruldu")
                            .font(.headline)
                    }
                    
                    if audioManager.isRecording {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Ses Seviyesi: \(Int(audioManager.audioLevel * 100))%")
                                .font(.caption)
                            
                            if audioManager.bpm > 0 {
                                Text("BPM: \(Int(audioManager.bpm))")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if !audioManager.isRecording && audioManager.musicSyncEnabled {
                    Button("Mikrofon İzni Gerekli") {
                        showingPermissionAlert = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Visualization Mode Picker
            if audioManager.isRecording {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Görselleştirme Modu")
                        .font(.headline)
                    
                    Picker("Visualization Mode", selection: $selectedVisualizationMode) {
                        Text("Spektrum").tag(0)
                        Text("Dalga Formu").tag(1)  
                        Text("Frekans Bandları").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
            }
            
            // Audio Visualization
            if audioManager.isRecording {
                VStack(spacing: 16) {
                    switch selectedVisualizationMode {
                    case 0:
                        SpectrumVisualizerView()
                    case 1:
                        WaveformVisualizerView() 
                    case 2:
                        FrequencyBandsView()
                    default:
                        SpectrumVisualizerView()
                    }
                }
                .frame(height: 200)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
            }
            
            // Audio Analysis Data
            if audioManager.isRecording {
                AudioDataView()
            }
            
            // Music Sync Settings
            VStack(alignment: .leading, spacing: 16) {
                Text("Senkronizasyon Ayarları")
                    .font(.headline)
                
                VStack(spacing: 12) {
                    // Sensitivity Settings
                    HStack {
                        Text("Bass Hassaslık")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: .constant(0.7), in: 0...1)
                        
                        Text("70%")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Renk Hassaslık")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: .constant(0.5), in: 0...1)
                        
                        Text("50%")
                            .frame(width: 40, alignment: .trailing)
                    }
                    
                    HStack {
                        Text("Beat Algılama")
                            .frame(width: 120, alignment: .leading)
                        
                        Slider(value: .constant(0.8), in: 0...1)
                        
                        Text("80%")
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .font(.caption)
                
                Divider()
                
                // Quick Presets
                HStack {
                    Text("Hızlı Ayarlar:")
                        .font(.subheadline)
                    
                    Button("Sakin") { /* Apply calm preset */ }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("Normal") { /* Apply normal preset */ }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    
                    Button("Enerji") { /* Apply energetic preset */ }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    
                    Spacer()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .alert("Mikrofon İzni", isPresented: $showingPermissionAlert) {
            Button("Ayarları Aç") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Müzik senkronizasyonu için mikrofon erişimi gerekli. Sistem Tercihleri > Güvenlik ve Gizlilik > Mikrofon bölümünden bu uygulamaya izin verin.")
        }
    }
}

struct SpectrumVisualizerView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<32, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan, .green, .yellow, .orange, .red],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 8)
                    .frame(height: spectrumHeight(for: index))
                    .animation(.easeOut(duration: 0.1), value: audioManager.audioLevel)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func spectrumHeight(for index: Int) -> CGFloat {
        // Simulate spectrum data based on frequency bands
        let bassWeight = index < 8 ? CGFloat(audioManager.bassLevel) : 0
        let midWeight = index >= 8 && index < 20 ? CGFloat(audioManager.midLevel) : 0
        let trebleWeight = index >= 20 ? CGFloat(audioManager.trebleLevel) : 0
        
        let height = (bassWeight + midWeight + trebleWeight) * 150 + CGFloat.random(in: 10...30)
        return max(4, height)
    }
}

struct WaveformVisualizerView: View {
    @EnvironmentObject var audioManager: AudioManager
    @State private var waveformPoints: [CGFloat] = Array(repeating: 0, count: 100)
    
    var body: some View {
        Canvas { context, size in
            let width = size.width
            let height = size.height
            let centerY = height / 2
            
            var path = Path()
            
            for (index, point) in waveformPoints.enumerated() {
                let x = (CGFloat(index) / CGFloat(waveformPoints.count - 1)) * width
                let y = centerY + (point * centerY * 0.8)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            
            context.stroke(path, with: .color(.cyan), lineWidth: 2)
        }
        .onReceive(Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()) { _ in
            updateWaveform()
        }
    }
    
    private func updateWaveform() {
        // Shift existing points left
        waveformPoints.removeFirst()
        
        // Add new point based on audio level
        let newPoint = CGFloat(audioManager.audioLevel) * 2 - 1 // Convert to -1 to 1 range
        waveformPoints.append(newPoint)
    }
}

struct FrequencyBandsView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        HStack(spacing: 20) {
            // Bass
            VStack {
                Text("BASS")
                    .font(.caption)
                    .foregroundColor(.white)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(.red)
                    .frame(width: 40, height: max(4, CGFloat(audioManager.bassLevel) * 150))
                
                Text("\(Int(audioManager.bassLevel * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            // Mid
            VStack {
                Text("MID")
                    .font(.caption)
                    .foregroundColor(.white)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(.green)
                    .frame(width: 40, height: max(4, CGFloat(audioManager.midLevel) * 150))
                
                Text("\(Int(audioManager.midLevel * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            // Treble
            VStack {
                Text("TREBLE")
                    .font(.caption)
                    .foregroundColor(.white)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(.blue)
                    .frame(width: 40, height: max(4, CGFloat(audioManager.trebleLevel) * 150))
                
                Text("\(Int(audioManager.trebleLevel * 100))%")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Dominant Frequency
            VStack {
                Text("DOMINANT FREQ")
                    .font(.caption)
                    .foregroundColor(.white)
                
                Circle()
                    .fill(Color(hue: min(Double(audioManager.dominantFrequency) / 20000, 1.0), saturation: 1, brightness: 1))
                    .frame(width: 60, height: 60)
                
                Text("\(Int(audioManager.dominantFrequency)) Hz")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
        }
        .padding()
    }
}

struct AudioDataView: View {
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ses Analizi Verileri")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DataCard(title: "Ses Seviyesi", value: "\(Int(audioManager.audioLevel * 100))%", color: .blue)
                DataCard(title: "Baskın Frekans", value: "\(Int(audioManager.dominantFrequency)) Hz", color: .purple)
                DataCard(title: "BPM", value: audioManager.bpm > 0 ? "\(Int(audioManager.bpm))" : "---", color: .green)
                DataCard(title: "Bass", value: "\(Int(audioManager.bassLevel * 100))%", color: .red)
                DataCard(title: "Mid", value: "\(Int(audioManager.midLevel * 100))%", color: .orange)
                DataCard(title: "Treble", value: "\(Int(audioManager.trebleLevel * 100))%", color: .cyan)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct DataCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    MusicSyncView()
        .environmentObject(AudioManager())
        .environmentObject(LEDController())
}