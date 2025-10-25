//
//  LEDController.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import Foundation
import SwiftUI
import Combine
import AppKit

class LEDController: ObservableObject {
    // MARK: - Published Properties
    @Published var currentColor = Color.red
    @Published var brightness: Double = 1.0
    @Published var speed: Double = 50
    @Published var selectedEffect: LEDEffect = .solid
    @Published var isAnimationEnabled = false
    @Published var stripLength = 60
    @Published var musicSyncEnabled = false
    
    // MARK: - Private Properties
    private var bluetoothManager: BluetoothManager?
    private var animationTimer: Timer?
    private var currentAnimationPhase: Double = 0
    
    // MARK: - LED Effects
    enum LEDEffect: String, CaseIterable, Identifiable {
        case solid = "Sabit Renk"
        case rainbow = "Gökkuşağı"
        case breathing = "Nefes Alma"
        case chase = "Kovalama"
        case strobe = "Yanıp Sönme"
        case fade = "Solma"
        case scanner = "Tarayıcı"
        case fire = "Ateş"
        case wave = "Dalga"
        case meteor = "Meteor"
        
        var id: String { rawValue }
        
        var description: String {
            switch self {
            case .solid: return "Tüm LED'ler aynı renkte yanar"
            case .rainbow: return "Renk spektrumunda döngü"
            case .breathing: return "Yumuşak parlaklık değişimi"
            case .chase: return "LED'ler sırayla yanıp söner"
            case .strobe: return "Hızlı yanıp sönme efekti"
            case .fade: return "Renkler arası yumuşak geçiş"
            case .scanner: return "İleri geri tarama efekti"
            case .fire: return "Ateş benzetimi efekti"
            case .wave: return "Dalga hareketi efekti"
            case .meteor: return "Meteor geçişi efekti"
            }
        }
        
        var systemImage: String {
            switch self {
            case .solid: return "circle.fill"
            case .rainbow: return "paintbrush.fill"
            case .breathing: return "lungs.fill"
            case .chase: return "arrow.right.circle.fill"
            case .strobe: return "bolt.fill"
            case .fade: return "gradient"
            case .scanner: return "radar"
            case .fire: return "flame.fill"
            case .wave: return "waveform"
            case .meteor: return "sparkles"
            }
        }
    }
    
    init() {
        setupAnimationTimer()
    }
    
    // MARK: - Public Methods
    func setBluetoothManager(_ manager: BluetoothManager) {
        self.bluetoothManager = manager
    }
    
    func updateColor(_ color: Color) {
        currentColor = color
        sendColorUpdate()
    }
    
    func updateBrightness(_ value: Double) {
        brightness = value
        // STARLIGHT: Parlaklık 0-1000 arası
        let starlightBrightness = Int(value * 1000)
        bluetoothManager?.starlightBrightness(starlightBrightness)
    }
    
    func updateSpeed(_ value: Double) {
        speed = value
        if isAnimationEnabled {
            // STARLIGHT: Hız 0-255 arası
            let starlightSpeed = Int((value / 100.0) * 255)
            bluetoothManager?.starlightSpeed(starlightSpeed)
        }
    }
    
    func setEffect(_ effect: LEDEffect) {
        selectedEffect = effect
        sendEffectUpdate()
    }
    
    func toggleAnimation() {
        isAnimationEnabled.toggle()
        
        if isAnimationEnabled {
            startAnimation()
        } else {
            stopAnimation()
            sendColorUpdate() // Sabit renk gönder
        }
    }
    
    func turnOff() {
        stopAnimation()
        isAnimationEnabled = false
        // STARLIGHT: Power OFF
        bluetoothManager?.starlightPower(on: false)
    }
    
    func turnOn() {
        // STARLIGHT: Power ON
        bluetoothManager?.starlightPower(on: true)
        // Kısa bir gecikme ile renk ve parlaklığı ayarla
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if !self.isAnimationEnabled {
                self.sendColorUpdate()
            }
        }
    }
    
    // MARK: - Music Sync Methods
    func enableMusicSync(_ enabled: Bool) {
        musicSyncEnabled = enabled
        if enabled {
            isAnimationEnabled = true
            startAnimation()
        }
    }
    
    func updateWithMusicData(bassLevel: Double, midLevel: Double, trebleLevel: Double, dominantFrequency: Double) {
        guard musicSyncEnabled else { return }
        
        // Bas seviyesine göre parlaklık
        let musicBrightness = max(0.2, bassLevel * brightness)
        
        // Frekansa göre renk
        let musicColor = colorFromFrequency(dominantFrequency)
        
        // Orta frekans seviyesine göre hız
        let musicSpeed = 20 + (midLevel * 80)
        
        sendMusicSyncUpdate(color: musicColor, brightness: musicBrightness, speed: musicSpeed)
    }
    
    // MARK: - Private Methods
    private func setupAnimationTimer() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) { _ in
            if self.isAnimationEnabled && !self.musicSyncEnabled {
                self.currentAnimationPhase += self.speed / 1000.0
                if self.currentAnimationPhase > 1.0 {
                    self.currentAnimationPhase = 0.0
                }
                self.sendEffectUpdate()
            }
        }
    }
    
    private func startAnimation() {
        isAnimationEnabled = true
        sendEffectUpdate()
    }
    
    private func stopAnimation() {
        isAnimationEnabled = false
        currentAnimationPhase = 0.0
    }
    
    private func sendColorUpdate() {
        let rgbColor = NSColor(currentColor)
        
        // Convert to RGB color space first to handle dynamic colors
        guard let srgbColor = rgbColor.usingColorSpace(.sRGB) else {
            print("❌ Could not convert color to sRGB")
            return
        }
        
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        srgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        // Convert RGB to HSV for STARLIGHT protocol
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
        let h = Int(hue)
        let s = Int(sat * 997)
        
        print("🎨 Sending HSV color: H:\(h)° S:\(s)/997 (brightness: \(Int(brightness * 100))%)")
        
        // STARLIGHT: HSV color control
        bluetoothManager?.starlightSetColorHSV(hue: h, saturation: s)
        
        // STARLIGHT: Brightness control
        let starlightBrightness = Int(brightness * 1000)
        bluetoothManager?.starlightBrightness(starlightBrightness)
    }
    
    private func sendEffectUpdate() {
        guard isAnimationEnabled else { return }
        
        switch selectedEffect {
        case .solid:
            sendColorUpdate()
            
        case .rainbow:
            sendCommand(.rainbow(Int(speed)))
            
        case .breathing:
            sendCommand(.breathing(currentColor, Int(speed)))
            
        case .chase:
            sendCommand(.chase(currentColor, Int(speed)))
            
        case .strobe:
            sendCommand(.strobe(currentColor, Int(speed)))
            
        case .fade:
            sendCommand(.fade(currentColor, Color.blue, Int(speed)))
            
        case .scanner:
            sendCommand(.scanner(currentColor, Int(speed)))
            
        case .fire:
            sendCommand(.fire(Int(speed)))
            
        case .wave:
            sendCommand(.wave(currentColor, Int(speed)))
            
        case .meteor:
            sendCommand(.meteor(currentColor, Int(speed)))
        }
    }
    
    private func sendMusicSyncUpdate(color: Color, brightness: Double, speed: Double) {
        let rgbColor = NSColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255 * brightness)
        let g = Int(green * 255 * brightness)
        let b = Int(blue * 255 * brightness)
        
        // Müzik senkronizasyonu için özel komut
        sendCommand(.musicSync(r, g, b, Int(speed)))
    }
    
    func updateMusicSync(color: Color, brightness: Double, speed: Double, bassLevel: Int, midLevel: Int, trebleLevel: Int, bpm: Int) {
        guard musicSyncEnabled else { return }
        
        // Rengi RGB'ye çevir
        let rgbColor = NSColor(color)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let r = Int(red * 255 * brightness)
        let g = Int(green * 255 * brightness)
        let b = Int(blue * 255 * brightness)
        
        // Beat based flash effect
        if bassLevel > 200 { // Strong bass
            currentColor = color
            self.brightness = brightness
            sendCommand(.flash(r, g, b, Int(speed)))
        } else {
            // Smooth color transition
            sendCommand(.musicSync(r, g, b, Int(speed)))
        }
    }
    
    private func colorFromFrequency(_ frequency: Double) -> Color {
        // Frekansı renk spektrumuna dönüştür
        let normalizedFreq = min(max(frequency / 20000.0, 0.0), 1.0) // 0-20kHz arası normalize et
        
        let hue = normalizedFreq * 360.0 // 0-360 derece hue
        return Color(hue: hue / 360.0, saturation: 1.0, brightness: 1.0)
    }
    
    private func sendCommand(_ command: LEDCommand) {
        guard let bluetoothManager = bluetoothManager else { return }
        
        switch command {
        case .turnOff:
            print("🔌 Toggle Power - Sending simple power command")
            if let bluetoothMgr = self.bluetoothManager {
                // Send only one safe power command
                bluetoothMgr.sendSimplePowerCommand()
            } else {
                print("❌ BluetoothManager not available")
            }
            
        case .setColor(let red, let green, let blue):
            print("🎨 Setting color: R:\(red) G:\(green) B:\(blue)")
            if let bluetoothMgr = self.bluetoothManager {
                // Send only one safe color command
                bluetoothMgr.sendSingleColorCommand(red: UInt8(red), green: UInt8(green), blue: UInt8(blue))
            } else {
                print("❌ BluetoothManager not available")
            }
            
        case .rainbow(let speed):
            // ESP32 komutları
            bluetoothManager.sendESP32Command("mode=1")
            bluetoothManager.sendESP32Command("step=\(Double(speed) / 100.0)")
            // BLE animation
            bluetoothManager.sendAnimationCommand(mode: .wheel, speed: speed)
            // WLED JSON
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 1,
                    "sx": speed
                ]]
            ])
            
        case .breathing(let color, let speed):
            let rgbColor = NSColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            
            bluetoothManager.sendESP32Command("mode=2")
            bluetoothManager.sendESP32Command("rgb(\(Int(r*255)),\(Int(g*255)),\(Int(b*255)))")
            bluetoothManager.sendESP32Command("step=\(Double(speed) / 100.0)")
            
        case .chase(let color, let speed):
            let rgbColor = NSColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
            rgbColor.getRed(&r, green: &g, blue: &b, alpha: nil)
            
            let color1 = (UInt32(r*255) << 16) | (UInt32(g*255) << 8) | UInt32(b*255)
            let color2: UInt32 = 0x000000
            bluetoothManager.sendAnimationCommand(mode: .chase(color1, color2, 5), speed: speed)
            
        case .strobe(let color, let speed):
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 12, // Strobe effect ID in WLED
                    "sx": speed,
                    "col": [NSColor(color).rgbArray]
                ]]
            ])
            
        case .fade(let color1, let color2, let speed):
            let rgb1 = NSColor(color1)
            let rgb2 = NSColor(color2)
            
            var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0
            var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0
            
            rgb1.getRed(&r1, green: &g1, blue: &b1, alpha: nil)
            rgb2.getRed(&r2, green: &g2, blue: &b2, alpha: nil)
            
            let colorInt1 = (UInt32(r1*255) << 16) | (UInt32(g1*255) << 8) | UInt32(b1*255)
            let colorInt2 = (UInt32(r2*255) << 16) | (UInt32(g2*255) << 8) | UInt32(b2*255)
            
            bluetoothManager.sendAnimationCommand(mode: .fade(colorInt1, colorInt2, 10), speed: speed)
            
        case .scanner(let color, let speed):
            bluetoothManager.sendAnimationCommand(mode: .scan, speed: speed)
            
        case .fire(let speed):
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 13, // Fire effect
                    "sx": speed
                ]]
            ])
            
        case .wave(let color, let speed):
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 2, // Wave effect
                    "sx": speed,
                    "col": [NSColor(color).rgbArray]
                ]]
            ])
            
        case .meteor(let color, let speed):
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 42, // Meteor effect
                    "sx": speed,
                    "col": [NSColor(color).rgbArray]
                ]]
            ])
            
        case .flash(let r, let g, let b, let speed):
            // Flash effect for beat sync
            bluetoothManager.sendBLEColorCommand(length: stripLength, red: r, green: g, blue: b, brightness: 255)
            bluetoothManager.sendWLEDCommand([
                "on": true,
                "seg": [[
                    "fx": 12, // Strobe/Flash effect
                    "sx": speed,
                    "col": [[r, g, b]]
                ]]
            ])
            
        case .musicSync(let r, let g, let b, let speed):
            // Müzik senkronizasyonu için optimize edilmiş komut
            bluetoothManager.sendBLEColorCommand(length: stripLength, red: r, green: g, blue: b, brightness: 255)
        }
    }
}

// MARK: - LED Command Enum
private enum LEDCommand {
    case turnOff
    case setColor(Int, Int, Int)
    case rainbow(Int)
    case breathing(Color, Int)
    case chase(Color, Int)
    case strobe(Color, Int)
    case fade(Color, Color, Int)
    case scanner(Color, Int)
    case fire(Int)
    case wave(Color, Int)
    case meteor(Color, Int)
    case flash(Int, Int, Int, Int)
    case musicSync(Int, Int, Int, Int)
}

// MARK: - NSColor Extension
extension NSColor {
    var rgbArray: [Int] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        return [Int(red * 255), Int(green * 255), Int(blue * 255)]
    }
}