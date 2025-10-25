//
//  ColorPickerView.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI
import AppKit

struct ColorPickerView: View {
    @EnvironmentObject var ledController: LEDController
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @State private var selectedColorTab = 0
    @State private var customColors: [Color] = []
    
    // Preset colors
    let presetColors: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .pink, .white,
        Color(red: 1.0, green: 0.5, blue: 0.0),  // Orange-red
        Color(red: 0.5, green: 1.0, blue: 0.0),  // Lime
        Color(red: 0.0, green: 1.0, blue: 0.5),  // Spring green
        Color(red: 0.0, green: 0.5, blue: 1.0),  // Sky blue
        Color(red: 0.5, green: 0.0, blue: 1.0),  // Violet
        Color(red: 1.0, green: 0.0, blue: 0.5),  // Hot pink
        Color(red: 0.5, green: 0.5, blue: 0.5),  // Gray
        Color(red: 0.2, green: 0.2, blue: 0.2)   // Dark gray
    ]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                VStack(alignment: .leading) {
                    Text("Renk Kontrolü")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("LED stribin rengini ve parlaklığını ayarlayın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Current Color Preview
            HStack(spacing: 16) {
                // Color Preview Circle
                Circle()
                    .fill(ledController.currentColor)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: ledController.currentColor.opacity(0.5), radius: 10)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Seçili Renk")
                        .font(.headline)
                    
                    let (r, g, b) = rgbValues(from: ledController.currentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RGB: \(r), \(g), \(b)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Hex: #\(hexValue(from: ledController.currentColor))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Brightness Control
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "sun.min.fill")
                        .foregroundColor(.orange)
                    
                    Text("Parlaklık")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(Int(ledController.brightness * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $ledController.brightness, in: 0...1)
                    .onChange(of: ledController.brightness) { newValue in
                        // STARLIGHT brightness: 0-1000
                        let brightnessValue = Int(newValue * 1000)
                        bluetoothManager.starlightBrightness(brightnessValue)
                    }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            // Color Selection Tabs
            VStack(spacing: 16) {
                // Tab Selector
                Picker("Color Selection", selection: $selectedColorTab) {
                    Text("Hazır Renkler").tag(0)
                    Text("Özel Renk").tag(1)
                    Text("Kayıtlı Renkler").tag(2)
                }
                .pickerStyle(.segmented)
                
                // Tab Content
                Group {
                    switch selectedColorTab {
                    case 0:
                        PresetColorsView(colors: presetColors) { color in
                            ledController.currentColor = color
                            let (h, s) = hsvValues(from: color)
                            bluetoothManager.starlightSetColorHSV(hue: h, saturation: s)
                        }
                        
                    case 1:
                        CustomColorView { color in
                            ledController.currentColor = color
                            let (h, s) = hsvValues(from: color)
                            bluetoothManager.starlightSetColorHSV(hue: h, saturation: s)
                        }
                        
                    case 2:
                        SavedColorsView(
                            savedColors: $customColors,
                            onColorSelected: { color in
                                ledController.currentColor = color
                                let (h, s) = hsvValues(from: color)
                                bluetoothManager.starlightSetColorHSV(hue: h, saturation: s)
                            }
                        )
                        
                    default:
                        EmptyView()
                    }
                }
                .frame(minHeight: 200)
            }
            
            Spacer()
        }
        .padding()
    }
    
    // Helper functions
    private func rgbValues(from color: Color) -> (Int, Int, Int) {
        let uiColor = NSColor(color)
        
        // Convert to RGB color space first to handle dynamic colors
        guard let rgbColor = uiColor.usingColorSpace(.sRGB) else {
            // Fallback: return a default color if conversion fails
            return (128, 128, 128) // Gray
        }
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return (
            Int(red * 255),
            Int(green * 255), 
            Int(blue * 255)
        )
    }
    
    private func hsvValues(from color: Color) -> (hue: Int, saturation: Int) {
        let uiColor = NSColor(color)
        
        // Convert to RGB first
        guard let rgbColor = uiColor.usingColorSpace(.sRGB) else {
            return (0, 0)
        }
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let maxC = max(red, green, blue)
        let minC = min(red, green, blue)
        let delta = maxC - minC
        
        var hue: CGFloat = 0
        if delta != 0 {
            if maxC == red {
                hue = 60 * (((green - blue) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == green {
                hue = 60 * (((blue - red) / delta) + 2)
            } else {
                hue = 60 * (((red - green) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        
        let sat = maxC == 0 ? 0 : (delta / maxC)
        
        // STARLIGHT protocol: H: 0-360, S: 0-997
        return (Int(hue), Int(sat * 997))
    }
    
    private func hexValue(from color: Color) -> String {
        let (r, g, b) = rgbValues(from: color)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

struct PresetColorsView: View {
    let colors: [Color]
    let onColorSelected: (Color) -> Void
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hazır Renkler")
                .font(.headline)
            
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    Button(action: { onColorSelected(color) }) {
                        Circle()
                            .fill(color)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Renk \(index + 1)")
                }
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

struct CustomColorView: View {
    @State private var selectedColor = Color.red
    let onColorSelected: (Color) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Özel Renk Seçici")
                .font(.headline)
            
            HStack {
                // macOS Color Picker - Direct sending on change
                ColorPicker("Renk seçin", selection: $selectedColor, supportsOpacity: false)
                    .labelsHidden()
                    .onChange(of: selectedColor) { newColor in
                        onColorSelected(newColor)
                    }
                
                Spacer()
                
                Button("Uygula") {
                    onColorSelected(selectedColor)
                }
                .buttonStyle(.borderedProminent)
            }
            
            // HSV Sliders for fine control
            VStack(spacing: 12) {
                Text("Manuel Ayarlama")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HSVColorControls(color: $selectedColor) { newColor in
                    onColorSelected(newColor)
                }
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

struct HSVColorControls: View {
    @Binding var color: Color
    let onChange: (Color) -> Void
    
    @State private var hue: Double = 0
    @State private var saturation: Double = 1
    
    var body: some View {
        VStack(spacing: 8) {
            // Hue Slider
            HStack {
                Text("Ton")
                    .frame(width: 70, alignment: .leading)
                Slider(value: $hue, in: 0...360)
                    .onChange(of: hue) { _ in updateColor() }
                Text("\(Int(hue))°")
                    .frame(width: 40, alignment: .trailing)
            }
            
            // Saturation Slider  
            HStack {
                Text("Doygunluk")
                    .frame(width: 70, alignment: .leading)
                Slider(value: $saturation, in: 0...1)
                    .onChange(of: saturation) { _ in updateColor() }
                Text("\(Int(saturation * 100))%")
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .font(.caption)
    }
    
    private func updateColor() {
        // Parlaklık üstteki slider'dan kontrol ediliyor, burada 1.0 kullan
        let newColor = Color(hue: hue / 360.0, saturation: saturation, brightness: 1.0)
        color = newColor
        onChange(newColor)
    }
}

struct SavedColorsView: View {
    @Binding var savedColors: [Color]
    let onColorSelected: (Color) -> Void
    
    let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 8)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Kayıtlı Renkler")
                    .font(.headline)
                
                Spacer()
                
                Button(action: clearSavedColors) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .help("Tüm kayıtlı renkleri temizle")
                .disabled(savedColors.isEmpty)
            }
            
            if savedColors.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bookmark")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    
                    Text("Henüz kayıtlı renk yok")
                        .foregroundColor(.secondary)
                    
                    Text("Özel renk sekmesinden renk seçip kaydetmeyi unutmayın")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(savedColors.enumerated()), id: \.offset) { index, color in
                        Button(action: { onColorSelected(color) }) {
                            Circle()
                                .fill(color)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Kayıtlı renk \(index + 1)")
                        .contextMenu {
                            Button("Sil", role: .destructive) {
                                savedColors.remove(at: index)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
    
    private func clearSavedColors() {
        savedColors.removeAll()
    }
}

#Preview {
    ColorPickerView()
        .environmentObject(LEDController())
}