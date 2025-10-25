//
//  ControlPanelView.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI

struct ControlPanelView: View {
    @EnvironmentObject var ledController: LEDController
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var audioManager: AudioManager
    
    var body: some View {
        VStack(spacing: 16) {
            // Quick Status Header
            HStack {
                StatusIndicator(
                    title: "Bluetooth",
                    isActive: bluetoothManager.isConnected,
                    activeColor: .green,
                    inactiveColor: .red,
                    icon: "antenna.radiowaves.left.and.right"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "LED Strip",
                    isActive: ledController.isAnimationEnabled,
                    activeColor: .blue,
                    inactiveColor: .gray,
                    icon: "lightbulb.fill"
                )
                
                Spacer()
                
                StatusIndicator(
                    title: "Music Sync",
                    isActive: audioManager.musicSyncEnabled,
                    activeColor: .purple,
                    inactiveColor: .gray,
                    icon: "music.note"
                )
            }
            
            // Quick Controls
            VStack(spacing: 12) {
                Text("Hızlı Kontroller")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    // Power Toggle
                    ControlButton(
                        title: ledController.isAnimationEnabled ? "Kapat" : "Aç",
                        icon: ledController.isAnimationEnabled ? "power" : "lightbulb.fill",
                        color: ledController.isAnimationEnabled ? .red : .green,
                        action: {
                            if ledController.isAnimationEnabled {
                                ledController.turnOff()
                            } else {
                                ledController.turnOn()
                            }
                        }
                    )
                    
                    // Music Sync Toggle
                    ControlButton(
                        title: "Music",
                        icon: "music.note",
                        color: audioManager.musicSyncEnabled ? .purple : .gray,
                        action: {
                            audioManager.toggleMusicSync()
                        }
                    )
                    
                    // Brightness Shortcut
                    ControlButton(
                        title: "Parlaklık",
                        icon: "sun.max.fill",
                        color: .orange,
                        action: {
                            // Cycle through brightness levels: 25%, 50%, 75%, 100%
                            let levels: [Double] = [0.25, 0.5, 0.75, 1.0]
                            let currentIndex = levels.firstIndex(of: ledController.brightness) ?? 0
                            let nextIndex = (currentIndex + 1) % levels.count
                            ledController.updateBrightness(levels[nextIndex])
                        }
                    )
                }
            }
            
            // Preset Effects
            VStack(alignment: .leading, spacing: 8) {
                Text("Hızlı Efektler")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach([
                        LEDController.LEDEffect.rainbow,
                        .breathing,
                        .chase,
                        .fire,
                        .wave,
                        .strobe
                    ], id: \.id) { effect in
                        QuickEffectButton(
                            effect: effect,
                            isActive: ledController.selectedEffect == effect && ledController.isAnimationEnabled
                        ) {
                            ledController.setEffect(effect)
                            if !ledController.isAnimationEnabled {
                                ledController.toggleAnimation()
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct StatusIndicator: View {
    let title: String
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isActive ? activeColor : inactiveColor)
                .scaleEffect(isActive ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isActive)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Circle()
                .fill(isActive ? activeColor : inactiveColor)
                .frame(width: 8, height: 8)
        }
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickEffectButton: View {
    let effect: LEDController.LEDEffect
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: effect.systemImage)
                    .font(.title3)
                    .foregroundColor(isActive ? .white : .primary)
                
                Text(effect.rawValue)
                    .font(.caption2)
                    .foregroundColor(isActive ? .white : .primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.vertical, 8)
            .background(isActive ? Color.accentColor : Color(NSColor.textBackgroundColor))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Color Presets Component
struct ColorPresetsPanel: View {
    @EnvironmentObject var ledController: LEDController
    
    let presetColors: [(String, Color)] = [
        ("Kırmızı", .red),
        ("Mavi", .blue),
        ("Yeşil", .green),
        ("Sarı", .yellow),
        ("Mor", .purple),
        ("Turuncu", .orange),
        ("Beyaz", .white),
        ("Pembe", .pink)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hızlı Renkler")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4),
                GridItem(.flexible(), spacing: 4)
            ], spacing: 4) {
                ForEach(Array(presetColors.enumerated()), id: \.offset) { index, preset in
                    Button(action: {
                        ledController.updateColor(preset.1)
                    }) {
                        Circle()
                            .fill(preset.1)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help(preset.0)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ControlPanelView()
        .environmentObject(LEDController())
        .environmentObject(BluetoothManager())
        .environmentObject(AudioManager())
}