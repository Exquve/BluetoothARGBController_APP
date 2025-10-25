//
//  EffectsView.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI

struct EffectsView: View {
    @EnvironmentObject var ledController: LEDController
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var selectedMode: Int = 1
    @State private var animationSpeed: Double = 128
    @State private var reverseDirection: Bool = false
    
    // STARLIGHT Animation Categories (from Python file)
    let animationCategories: [(name: String, icon: String, range: ClosedRange<Int>)] = [
        ("7 Renk Gradient", "paintbrush.fill", 1...4),
        ("Farklı Animasyonlar", "wand.and.stars", 5...44),
        ("Özel Efektler", "sparkles", 45...95),
        ("Nokta Animasyonları", "circle.grid.3x3.fill", 96...117)
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.yellow)
                
                VStack(alignment: .leading) {
                    Text("LED Efektleri")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("117+ hazır animasyon modu ile LED şeridinizi özelleştirin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Current Mode Status
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Aktif Mod")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: "wand.and.stars.inverse")
                            .foregroundColor(.purple)
                        
                        Text("Mod \(selectedMode)")
                            .font(.headline)
                    }
                }
                
                Spacer()
                
                // Speed Control
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Hız")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(animationSpeed))")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("/ 255")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Speed Slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundColor(.blue)
                    
                    Text("Animasyon Hızı")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(reverseDirection ? "↔️ Ters" : "↔️ Normal") {
                        reverseDirection.toggle()
                        bluetoothManager.starlightDirection(reverse: reverseDirection)
                    }
                    .buttonStyle(.bordered)
                }
                
                Slider(value: $animationSpeed, in: 0...255, step: 1)
                    .onChange(of: animationSpeed) { newValue in
                        bluetoothManager.starlightSpeed(Int(newValue))
                    }
                
                HStack {
                    Text("Yavaş (0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Hızlı (255)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Animation Categories
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(animationCategories.enumerated()), id: \.offset) { index, category in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category Header
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(.accentColor)
                                
                                Text(category.name)
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("Mod \(category.range.lowerBound)-\(category.range.upperBound)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            
                            // Mode Grid
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 60), spacing: 8)
                            ], spacing: 8) {
                                ForEach(Array(category.range), id: \.self) { mode in
                                    ModeButton(
                                        mode: mode,
                                        isSelected: selectedMode == mode,
                                        onSelect: {
                                            selectedMode = mode
                                            bluetoothManager.starlightMode(mode)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

struct ModeButton: View {
    let mode: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text("\(mode)")
                    .font(.headline)
                    .foregroundColor(isSelected ? .white : .primary)
                
                if isSelected {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 4, height: 4)
                } else {
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(width: 60, height: 50)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EffectsView()
        .environmentObject(LEDController())
        .environmentObject(BluetoothManager())
}

// MARK: - Effect Preview Component
struct EffectPreviewView: View {
    let effect: LEDController.LEDEffect
    @State private var animationPhase: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { index in
                    Rectangle()
                        .fill(colorForLED(at: index, in: 8))
                        .frame(height: 4)
                        .cornerRadius(2)
                }
            }
        }
        .frame(height: 4)
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                animationPhase = 1.0
            }
        }
    }
    
    private func colorForLED(at index: Int, in total: Int) -> Color {
        let progress = Double(index) / Double(total - 1)
        
        switch effect {
        case .solid:
            return .red
        case .rainbow:
            return Color(hue: (progress + animationPhase).truncatingRemainder(dividingBy: 1.0), saturation: 1, brightness: 1)
        case .breathing:
            let intensity = 0.3 + 0.7 * abs(sin(animationPhase * .pi * 2))
            return Color.red.opacity(intensity)
        case .chase:
            let chasePosition = (animationPhase * Double(total)).truncatingRemainder(dividingBy: Double(total))
            let distance = abs(Double(index) - chasePosition)
            return distance < 2 ? .red : .clear
        case .strobe:
            return animationPhase.truncatingRemainder(dividingBy: 0.2) < 0.1 ? .red : .clear
        case .fade:
            let fadePhase = (animationPhase * 2).truncatingRemainder(dividingBy: 2.0)
            let color1 = Color.red
            let color2 = Color.blue
            return fadePhase < 1 ? color1 : color2
        case .scanner:
            let scanPosition = abs(sin(animationPhase * .pi)) * Double(total - 1)
            let distance = abs(Double(index) - scanPosition)
            return distance < 1 ? .red : .clear
        case .fire:
            let flicker = 0.7 + 0.3 * Double.random(in: 0...1)
            let fireColor = Color(hue: 0.08, saturation: 1, brightness: flicker)
            return index < 6 ? fireColor : .clear
        case .wave:
            let wave = sin(progress * .pi * 2 + animationPhase * .pi * 2)
            let intensity = (wave + 1) / 2
            return Color.blue.opacity(intensity)
        case .meteor:
            let meteorPos = (animationPhase * Double(total * 2)).truncatingRemainder(dividingBy: Double(total))
            let trail = max(0, 3 - abs(Double(index) - meteorPos))
            return trail > 0 ? Color.white.opacity(trail / 3) : .clear
        }
    }
}

#Preview {
    EffectsView()
        .environmentObject(LEDController())
}