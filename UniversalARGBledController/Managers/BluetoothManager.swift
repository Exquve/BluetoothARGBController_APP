//
//  BluetoothManager.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import Foundation
import CoreBluetooth
import Combine

class BluetoothManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isBluetoothOn = false
    @Published var isConnected = false
    @Published var discoveredDevices: [CBPeripheral] = []
    @Published var connectedDevice: CBPeripheral?
    @Published var connectionStatus = "Bağlantı Bekleniyor"
    
    // MARK: - Private Properties
    private var centralManager: CBCentralManager!
    private var ledControlCharacteristic: CBCharacteristic?
    private var colorCharacteristic: CBCharacteristic?
    private var stripConfigCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?
    
    // MARK: - Universal ARGB Controller Service & Characteristic UUIDs
    // Bu UUID'ler analiz ettiğimiz projelerden öğrendiklerimize dayanıyor
    struct ServiceUUIDs {
        // WLED-style service UUID (populer olan)
        static let ledService = CBUUID(string: "3F1D00C0-632F-4E53-9A14-437DD54BCCCB")
        
        // Generic LED services (diğer kontrolcüler için)
        static let genericLedService = CBUUID(string: "0000FFE0-0000-1000-8000-00805F9B34FB")
        static let customLedService = CBUUID(string: "12345678-1234-1234-1234-123456789ABC")
    }
    
    struct CharacteristicUUIDs {
        // NeoPixel color control
        static let neopixelColor = CBUUID(string: "3F1D00C2-632F-4E53-9A14-437DD54BCCCB")
        // NeoPixel animation control  
        static let neopixelAnima = CBUUID(string: "3F1D00C3-632F-4E53-9A14-437DD54BCCCB")
        // NeoPixel strip configuration
        static let neopixelStrip = CBUUID(string: "3F1D00C1-632F-4E53-9A14-437DD54BCCCB")
        
        // Generic characteristics for other controllers
        static let genericWrite = CBUUID(string: "0000FFE1-0000-1000-8000-00805F9B34FB")
        static let customCommand = CBUUID(string: "12345678-1234-1234-1234-123456789ABD")
    }
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            connectionStatus = "Bluetooth Kapalı"
            return
        }
        
        connectionStatus = "Cihazlar Aranıyor..."
        discoveredDevices.removeAll()
        
        // Hem belirli servisler hem de genel tarama yapıyoruz
        let services = [
            ServiceUUIDs.ledService,
            ServiceUUIDs.genericLedService
        ]
        
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        connectionStatus = "Tarama Durduruldu"
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionStatus = "Bağlanıyor: \(peripheral.name ?? "Bilinmeyen Cihaz")"
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let device = connectedDevice {
            centralManager.cancelPeripheralConnection(device)
        }
    }
    
    // MARK: - LED Control Commands
    
    /// Safe power ON commands
    func sendPowerOnCommands() {
        guard let device = connectedDevice, let char = writeCharacteristic else {
            print("❌ No device or write characteristic for power commands")
            return
        }
        
        print("🔌 Sending safe Power ON commands...")
        
        // Only send the most common power ON formats
        let powerCommands: [(String, Data)] = [
            ("Simple Power ON", Data([0x01])),
            ("HappyLighting Power", Data([0x7E, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00, 0xEF])),
            ("Generic Power", Data([0xCC, 0x23, 0x33]))
        ]
        
        for (name, data) in powerCommands {
            device.writeValue(data, for: char, type: .withoutResponse)
            print("📤 \(name): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            Thread.sleep(forTimeInterval: 0.1) // 100ms delay
        }
        
        print("✅ Safe power commands sent")
    }
    
    /// URGENT: Test SIMPLE minimal protocols - maybe STARLIGHT uses very basic commands
    func emergencyProtocolTest() {
        guard let device = connectedDevice else {
            print("❌ No device for emergency test")
            return
        }
        
        print("� MINIMAL PROTOCOL TEST - Testing SIMPLEST possible commands")
        
        // Find all writable characteristics
        var writableChars: [CBCharacteristic] = []
        for service in device.services ?? [] {
            for char in service.characteristics ?? [] {
                if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                    writableChars.append(char)
                }
            }
        }
        
        print("📝 Found \(writableChars.count) writable characteristics")
        
        // ULTRA SIMPLE protocols - maybe STARLIGHT is very basic
        let minimalCommands: [(String, [UInt8])] = [
            // Single bytes - power control?
            ("⚡ Power 1", [0x01]),
            ("⚡ Power 2", [0x02]), 
            ("⚡ Power 0", [0x00]),
            ("⚡ Power FF", [0xFF]),
            
            // 2-byte commands
            ("🔴 2-byte 1", [0x01, 0xFF]),
            ("🔴 2-byte 2", [0xFF, 0x01]),
            ("🔴 2-byte 3", [0x00, 0xFF]),
            
            // 3-byte pure RGB
            ("🔴 Pure RED", [0xFF, 0x00, 0x00]),
            ("🟢 Pure GREEN", [0x00, 0xFF, 0x00]), 
            ("🔵 Pure BLUE", [0x00, 0x00, 0xFF]),
            ("⚪ Pure WHITE", [0xFF, 0xFF, 0xFF]),
            
            // 4-byte RGBW
            ("🔴 RGBW RED", [0xFF, 0x00, 0x00, 0x00]),
            ("⚪ RGBW WHITE", [0x00, 0x00, 0x00, 0xFF]),
            
            // Classic prefixes with minimal data
            ("📟 AA prefix", [0xAA, 0xFF, 0x00, 0x00]),
            ("📟 55 prefix", [0x55, 0xFF, 0x00, 0x00]),
            ("📟 01 prefix", [0x01, 0xFF, 0x00, 0x00]),
            ("📟 FF prefix", [0xFF, 0xFF, 0x00, 0x00])
        ]
        
        for (index, char) in writableChars.enumerated() {
            print("🔍 Testing characteristic \(index + 1)/\(writableChars.count): \(char.uuid)")
            
            for (name, bytes) in minimalCommands {
                let data = Data(bytes)
                device.writeValue(data, for: char, type: .withoutResponse)
                print("   📤 \(name): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                usleep(2000000) // 2 seconds wait - easier to see changes
            }
            
            print("   ⏳ Tested \(minimalCommands.count) minimal commands on \(char.uuid)")
        }
        
        print("✅ Minimal protocol test complete - Any LED activity?")
    }
    
    /// Send a simple power command (crash-safe) - Test multiple formats
    func sendSimplePowerCommand() {
        guard let device = connectedDevice, let char = writeCharacteristic else {
            print("❌ No device or write characteristic for power command")
            return
        }
        
        print("🔌 Testing STARLIGHT power protocols...")
        
        // Test 1: Simple power toggle
        let powerToggle1 = Data([0x01])
        device.writeValue(powerToggle1, for: char, type: .withoutResponse)
        print("📤 Simple Toggle: \(powerToggle1.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Test 2: ELK-BLEDOM power on
            let elkPowerOn = Data([0x7e, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00, 0xef])
            device.writeValue(elkPowerOn, for: char, type: .withoutResponse)
            print("📤 ELK Power ON: \(elkPowerOn.map { String(format: "%02X", $0) }.joined(separator: " "))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Test 3: ELK-BLEDOM power off
                let elkPowerOff = Data([0x7e, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00, 0xef])
                device.writeValue(elkPowerOff, for: char, type: .withoutResponse)
                print("📤 ELK Power OFF: \(elkPowerOff.map { String(format: "%02X", $0) }.joined(separator: " "))")
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    // Test 4: Triones power commands
                    let trionesPowerOn = Data([0xcc, 0x23, 0x33])
                    device.writeValue(trionesPowerOn, for: char, type: .withoutResponse)
                    print("📤 Triones Power ON: \(trionesPowerOn.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let trionesPowerOff = Data([0xcc, 0x24, 0x33])
                        device.writeValue(trionesPowerOff, for: char, type: .withoutResponse)
                        print("📤 Triones Power OFF: \(trionesPowerOff.map { String(format: "%02X", $0) }.joined(separator: " "))")
                    }
                }
            }
        }
    }
    
    /// Send single color command (crash-safe) - Test multiple protocols
    func sendSingleColorCommand(red: UInt8, green: UInt8, blue: UInt8) {
        guard let device = connectedDevice,
              let characteristic = writeCharacteristic else {
            print("❌ No connected device or characteristic")
            return
        }
        
        print("🎨 Testing STARLIGHT specific protocols - R:\(red) G:\(green) B:\(blue)")
        
        // Test 1: Very simple - just RGB
        let simpleRGB = Data([red, green, blue])
        device.writeValue(simpleRGB, for: characteristic, type: .withoutResponse)
        print("📤 Simple RGB: \(simpleRGB.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Test 2: WRGB format (White + RGB)
            let wrgb = Data([0x00, red, green, blue])
            device.writeValue(wrgb, for: characteristic, type: .withoutResponse)
            print("📤 WRGB Format: \(wrgb.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            // Test 3: Common Chinese format with 0xFF prefix
            let prefix = Data([0xFF, red, green, blue])
            device.writeValue(prefix, for: characteristic, type: .withoutResponse)
            print("📤 0xFF Prefix: \(prefix.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            // Test 4: ELK-BLEDOM style (very common in Chinese controllers)
            let elkBledom = Data([0x7e, 0x00, 0x05, 0x03, red, green, blue, 0x00, 0xef])
            device.writeValue(elkBledom, for: characteristic, type: .withoutResponse)
            print("📤 ELK-BLEDOM: \(elkBledom.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            // Test 5: Triones/HappyLighting protocol
            let triones = Data([0x56, red, green, blue, 0x00, 0xf0, 0xaa])
            device.writeValue(triones, for: characteristic, type: .withoutResponse)
            print("📤 Triones: \(triones.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            // Test 6: Magic Blue protocol
            let magicBlue = Data([red, green, blue, 0x00, 0xf0, 0x0f])
            device.writeValue(magicBlue, for: characteristic, type: .withoutResponse)
            print("📤 Magic Blue: \(magicBlue.map { String(format: "%02X", $0) }.joined(separator: " "))")
        }
    }
    
    /// Send optimized color commands with only the 4 most promising protocols
    func sendOptimizedColorCommands(r: Int, g: Int, b: Int) {
        guard let device = connectedDevice,
              let char = ledControlCharacteristic else {
            print("❌ No device or characteristic for color commands")
            return
        }
        
        print("🎯 Sending 4 optimized protocols for RGB(\(r),\(g),\(b))")
        
        usleep(100000) // 100ms delay after power commands
        
        // Test the most common working formats one by one
        // 1. Simple RGB (3 bytes) - most basic format
        let simpleRGB = Data([UInt8(r), UInt8(g), UInt8(b)])
        device.writeValue(simpleRGB, for: char, type: .withResponse)
        print("📤 Simple RGB: \(simpleRGB.map { String(format: "%02X", $0) }.joined(separator: " "))")
        usleep(50000)
        
        // 2. MagicHome format (common in AppStore apps)
        let magicHome = Data([0x31, UInt8(r), UInt8(g), UInt8(b), 0x00, 0xF0, 0x0F])
        device.writeValue(magicHome, for: char, type: .withResponse)
        print("📤 MagicHome: \(magicHome.map { String(format: "%02X", $0) }.joined(separator: " "))")
        usleep(50000)
        
        // 3. LED BLE format (very common)
        let ledBLE = Data([0x56, UInt8(r), UInt8(g), UInt8(b), 0x00, 0xF0, 0xAA])
        device.writeValue(ledBLE, for: char, type: .withResponse)
        print("📤 LED BLE: \(ledBLE.map { String(format: "%02X", $0) }.joined(separator: " "))")
        usleep(50000)
        
        // 4. ELK-BLEDOM format
        let elkBledom = Data([0x7E, 0x00, 0x03, UInt8(r), UInt8(g), UInt8(b), 0x00, 0xEF])
        device.writeValue(elkBledom, for: char, type: .withResponse)
        print("📤 ELK-BLEDOM: \(elkBledom.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        print("✅ Sent 4 optimized protocols")
    }
    
    /// Test both FFF3 and FFF4 characteristics with universal commands
    func testBothCharacteristics(red: UInt8, green: UInt8, blue: UInt8) {
        guard let device = connectedDevice else {
            print("❌ No connected device")
            return
        }
        
        // Find both characteristics
        var fff3Char: CBCharacteristic?
        var fff4Char: CBCharacteristic?
        
        for service in device.services ?? [] {
            for characteristic in service.characteristics ?? [] {
                if characteristic.uuid.uuidString == "FFF3" {
                    fff3Char = characteristic
                } else if characteristic.uuid.uuidString == "FFF4" {
                    fff4Char = characteristic
                }
            }
        }
        
        // Test FFF3 first (write characteristic)
        if let char = fff3Char {
            print("🔄 Testing FFF3 characteristic...")
            testUniversalFormatsOnCharacteristic(char, red: red, green: green, blue: blue)
        }
        
        // Test FFF4 (notify characteristic) - some controllers use this for commands too
        if let char = fff4Char {
            print("🔄 Testing FFF4 characteristic...")
            testUniversalFormatsOnCharacteristic(char, red: red, green: green, blue: blue)
        }
    }
    
    private func testUniversalFormatsOnCharacteristic(_ characteristic: CBCharacteristic, red: UInt8, green: UInt8, blue: UInt8) {
        guard let device = connectedDevice else { return }
        
        // Most common AppStore compatible formats
        let formats: [(String, Data)] = [
            ("MagicHome", Data([0x31, red, green, blue, 0x00, 0xF0, 0x0F])),
            ("Govee", Data([0x33, 0x01, red, green, blue, 0x00, 0x00, 0x00])),
            ("ELK-BLEDOM", Data([0x7E, 0x00, 0x03, red, green, blue, 0x00, 0xEF])),
            ("LED BLE", Data([0x56, red, green, blue, 0x00, 0xF0, 0xAA])),
            ("Triones", Data([0x56, red, green, blue, 0x00, 0xF0, 0xAA])),
            ("Simple RGB", Data([red, green, blue])),
            ("RGBA", Data([red, green, blue, 0xFF])),
            ("Generic", Data([0xCC, red, green, blue, 0x33]))
        ]
        
        for (name, data) in formats {
            device.writeValue(data, for: characteristic, type: .withResponse)
            print("📤 \(characteristic.uuid.uuidString) - \(name): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            usleep(50000) // 50ms delay between commands
        }
    }
    
    /// ESP32 style string commands (ESP32-WS2812B-Controller protokolü)
    func sendESP32Command(_ command: String) {
        guard let characteristic = ledControlCharacteristic else { 
            print("❌ ESP32 Command failed: No ledControlCharacteristic available")
            return 
        }
        let data = Data(command.utf8)
        print("📤 ESP32 Command: '\(command)' -> \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        connectedDevice?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Internet-researched comprehensive protocol testing  
    func comprehensiveProtocolTest() {
        guard let device = connectedDevice else {
            print("❌ No device for comprehensive test")
            return
        }
        
        print("🌍 COMPREHENSIVE INTERNET PROTOCOL TEST - Testing ALL researched universal formats")
        
        // Analyze all services and characteristics in detail
        for service in device.services ?? [] {
            print("\n🔧 SERVICE: \(service.uuid)")
            
            for char in service.characteristics ?? [] {
                let props = char.properties
                let writeType: String = props.contains(.write) ? "WITH_RESPONSE" : 
                                       props.contains(.writeWithoutResponse) ? "WITHOUT_RESPONSE" : "READ_ONLY"
                print("   📝 \(char.uuid) - \(writeType)")
                
                if props.contains(.write) || props.contains(.writeWithoutResponse) {
                    testAllUniversalProtocols(on: char, device: device)
                }
            }
        }
        
        print("\n✅ Comprehensive internet protocol test complete!")
    }
    
    /// Test all internet-researched protocols on a single characteristic
    private func testAllUniversalProtocols(on characteristic: CBCharacteristic, device: CBPeripheral) {
        // From GitHub research - ALL major BLE LED protocols
        let protocols: [(String, [UInt8])] = [
            // TRIONES Protocol (most common - 0x56 prefix)
            ("🟥 Triones RED", [0x56, 0xFF, 0x00, 0x00, 0x00, 0xF0, 0xAA]),
            ("🟢 Triones GREEN", [0x56, 0x00, 0xFF, 0x00, 0x00, 0xF0, 0xAA]),
            ("🔵 Triones BLUE", [0x56, 0x00, 0x00, 0xFF, 0x00, 0xF0, 0xAA]),
            ("⚪ Triones WHITE", [0x56, 0x00, 0x00, 0x00, 0xFF, 0xF0, 0xAA]),
            
            // TRIONES Power & Built-in modes  
            ("⚡ Triones ON", [0xCC, 0x23, 0x33]),
            ("🔴 Triones OFF", [0xCC, 0x24, 0x33]),
            ("🌈 Triones Mode1", [0xBB, 0x25, 0x10, 0x44]),    // Seven color cross fade
            ("💫 Triones Mode2", [0xBB, 0x26, 0x10, 0x44]),    // Red gradual change
            ("✨ Triones Mode3", [0xBB, 0x27, 0x10, 0x44]),    // Green gradual change
            
            // ZJ-MBL-RGBW Protocol (Alternative Triones)
            ("🔴 ZJ RED", [0x56, 0xFF, 0x00, 0x00, 0x00, 0x0F, 0xAA]),
            ("🔸 ZJ Mode Flash", [0xBB, 0x27, 0x10, 0x44]),
            
            // ELK-BLEDOM Protocol (0x7E prefix) - Very common
            ("🟥 ELK RED", [0x7E, 0x00, 0x05, 0x03, 0xFF, 0x00, 0x00, 0x00, 0xEF]),
            ("🟢 ELK GREEN", [0x7E, 0x00, 0x05, 0x03, 0x00, 0xFF, 0x00, 0x00, 0xEF]),
            ("🔵 ELK BLUE", [0x7E, 0x00, 0x05, 0x03, 0x00, 0x00, 0xFF, 0x00, 0xEF]),
            ("⚡ ELK Power ON", [0x7E, 0x00, 0x04, 0x01, 0x01, 0x00, 0x00, 0x00, 0xEF]),
            ("🔴 ELK Power OFF", [0x7E, 0x00, 0x04, 0x01, 0x00, 0x00, 0x00, 0x00, 0xEF]),
            
            // MAGIC HOME / LEDENET Protocol
            ("🟥 Magic RED", [0x31, 0xFF, 0x00, 0x00, 0x00, 0x0F]),
            ("🟢 Magic GREEN", [0x31, 0x00, 0xFF, 0x00, 0x00, 0x0F]),
            ("⚡ Magic ON", [0x71, 0x23, 0x0F]),
            ("🔴 Magic OFF", [0x71, 0x24, 0x0F]),
            
            // GOVEE Protocol
            ("🟥 Govee RED", [0x33, 0x01, 0xFF, 0x00, 0x00]),
            ("🟢 Govee GREEN", [0x33, 0x01, 0x00, 0xFF, 0x00]),
            ("🔵 Govee BLUE", [0x33, 0x01, 0x00, 0x00, 0xFF]),
            
            // LEDBLE / MagicBlue variants
            ("🔴 MagicBlue 1", [0x56, 0xFF, 0x00, 0x00, 0x00, 0x0F, 0xAA]),
            ("🔴 MagicBlue 2", [0x31, 0xFF, 0x00, 0x00, 0x00, 0xF0, 0x0F]),
            
            // Status Queries (universal)
            ("❓ Status Query 1", [0xEF, 0x01, 0x77]),
            ("❓ Status Query 2", [0x81, 0x8A, 0x8B]),
            ("❓ Query All", [0xF0, 0x01, 0x02, 0x03]),
            
            // Simple formats (fallback)
            ("🔴 Simple RED", [0xFF, 0x00, 0x00]),
            ("🟢 Simple GREEN", [0x00, 0xFF, 0x00]),
            ("🔴 WRGB RED", [0x00, 0xFF, 0x00, 0x00]),
            ("🔴 Prefix RED", [0x01, 0xFF, 0x00, 0x00]),
            
            // Alternative Chinese manufacturers
            ("🔴 Alt Chinese 1", [0xA1, 0xFF, 0x00, 0x00]),
            ("🔴 Alt Chinese 2", [0x80, 0x01, 0xFF, 0x00, 0x00]),
            ("🔴 Alt Chinese 3", [0x55, 0xFF, 0x00, 0x00, 0xAA])
        ]
        
        print("      🧪 Testing \(protocols.count) universal protocols on \(characteristic.uuid)...")
        
        for (index, (name, bytes)) in protocols.enumerated() {
            let data = Data(bytes)
            let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.writeWithoutResponse) ? .withoutResponse : .withResponse
            device.writeValue(data, for: characteristic, type: writeType)
            
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            print("         \(index+1)/\(protocols.count) \(name): \(hexString)")
            
            usleep(1200000) // 1.2 seconds - give enough time to see LED changes
        }
    }

    /// BRUTE FORCE: Test systematic hex combinations to crack STARLIGHT protocol
    func reverseEngineerProtocol() {
        guard let device = connectedDevice else {
            print("❌ No device for brute force test")
            return
        }
        
        print("� BRUTE FORCE MODE - Systematic hex testing to crack STARLIGHT!")
        
        guard let writeChar = device.services?.first?.characteristics?.first(where: { 
            $0.uuid.uuidString == "FFF3" 
        }) else {
            print("❌ No FFF3 write characteristic found")
            return
        }
        
        print("� Found FFF3 write characteristic - starting systematic test...")
        print("⚠️ This will test many combinations - watch LED strip carefully!")
        
        // SYSTEMATIC HEX TESTING
        // Test 1: Single bytes (power commands)
        print("\n🔥 PHASE 1: Testing single bytes (0x00-0xFF)")
        for i in 0...255 {
            let data = Data([UInt8(i)])
            device.writeValue(data, for: writeChar, type: .withoutResponse)
            print("📤 Single byte [\(String(format: "%02X", i))]: \(String(format: "%02X", i))")
            usleep(500000) // 500ms - fast enough to see changes
            
            // Test critical values immediately
            if [0x01, 0x02, 0x10, 0x20, 0x78, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF].contains(i) {
                usleep(1500000) // Extra wait for important values
            }
        }
        
        print("\n� PHASE 2: Testing 2-byte combinations")
        let criticalBytes: [UInt8] = [0x00, 0x01, 0x02, 0x10, 0x20, 0x56, 0x78, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        
        for first in criticalBytes {
            for second in criticalBytes {
                let data = Data([first, second])
                device.writeValue(data, for: writeChar, type: .withoutResponse)
                print("� 2-byte [\(String(format: "%02X", first)) \(String(format: "%02X", second))]: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                usleep(300000) // 300ms
            }
        }
        
        print("\n� PHASE 3: Testing RGB with different prefixes")
        let prefixes: [UInt8] = [0x00, 0x01, 0x02, 0x10, 0x20, 0x56, 0x7E, 0x78, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
        
        for prefix in prefixes {
            // Test RED with this prefix
            let redData = Data([prefix, 0xFF, 0x00, 0x00])
            device.writeValue(redData, for: writeChar, type: .withoutResponse)
            print("� RED with prefix [\(String(format: "%02X", prefix))]: \(redData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            usleep(800000) // 800ms - longer for color changes
            
            // Test WHITE with this prefix
            let whiteData = Data([prefix, 0xFF, 0xFF, 0xFF])
            device.writeValue(whiteData, for: writeChar, type: .withoutResponse)
            print("📤 WHITE with prefix [\(String(format: "%02X", prefix))]: \(whiteData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            usleep(800000)
        }
        
        print("\n🔥 PHASE 4: Testing RGB with different suffixes")
        let suffixes: [UInt8] = [0x00, 0x01, 0x0F, 0x33, 0x44, 0x77, 0xAA, 0xEF, 0xFF]
        
        for suffix in suffixes {
            let redData = Data([0xFF, 0x00, 0x00, suffix])
            device.writeValue(redData, for: writeChar, type: .withoutResponse)
            print("📤 RED with suffix [\(String(format: "%02X", suffix))]: \(redData.map { String(format: "%02X", $0) }.joined(separator: " "))")
            usleep(800000)
        }
        
    }
    
    /// DISCOVER ALL SERVICES: Find all BLE services and characteristics on STARLIGHT
    func discoverAllServices() {
        guard let device = connectedDevice else {
            print("❌ No device for service discovery")
            return
        }
        
        print("🔍 COMPLETE SERVICE DISCOVERY - Finding all STARLIGHT services!")
        print("🎯 Device: \(device.name ?? "Unknown") (\(device.identifier.uuidString))")
        
        guard let services = device.services, !services.isEmpty else {
            print("❌ No services found! Re-discovering services...")
            device.discoverServices(nil) // Discover ALL services
            return
        }
        
        print("\n📡 FOUND \(services.count) SERVICE(S):")
        
        for (serviceIndex, service) in services.enumerated() {
            print("\n🔧 SERVICE #\(serviceIndex + 1): \(service.uuid.uuidString)")
            print("   📍 Primary: \(service.isPrimary)")
            
            if let characteristics = service.characteristics {
                print("   � \(characteristics.count) CHARACTERISTIC(S):")
                
                for (charIndex, char) in characteristics.enumerated() {
                    let props = char.properties
                    print("      📌 CHAR #\(charIndex + 1): \(char.uuid.uuidString)")
                    print("         🔹 Read: \(props.contains(.read))")
                    print("         🔹 Write: \(props.contains(.write))")
                    print("         🔹 WriteNoResp: \(props.contains(.writeWithoutResponse))")
                    print("         🔹 Notify: \(props.contains(.notify))")
                    print("         🔹 Indicate: \(props.contains(.indicate))")
                    
                    // Test EVERY writable characteristic!
                    if props.contains(.write) || props.contains(.writeWithoutResponse) {
                        print("         🚀 TESTING write capability...")
                        testCharacteristic(char, on: device, serviceIndex: serviceIndex + 1, charIndex: charIndex + 1)
                    }
                    
                    // Enable notifications on every notify characteristic
                    if props.contains(.notify) {
                        print("         🔔 ENABLING notifications...")
                        device.setNotifyValue(true, for: char)
                    }
                }
            } else {
                print("   ⚠️ No characteristics discovered yet! Discovering...")
                device.discoverCharacteristics(nil, for: service)
            }
        }
        
    }
    
    // ============================================
    // STARLIGHT PROTOCOL - WORKING VERSION
    // From starlight_final.py - Reverse engineered
    // ============================================
    
    /// STARLIGHT RGB Color Control (ALL LEDs)
    func starlightSetColor(red: UInt8, green: UInt8, blue: UInt8) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        // Convert RGB to HSV
        let (hue, sat, val) = rgbToHSV(r: red, g: green, b: blue)
        
        // Check if white color
        let isWhite = (red == 255 && green == 255 && blue == 255)
        
        let command: [UInt8]
        if isWhite {
            // White: special case
            command = [
                0xBC, 0x04, 0x06,
                UInt8(hue / 255), UInt8(hue % 255),
                0x00, 0x00,  // White uses 0, 0
                0x00, 0x00,
                red, green, blue,
                0x55
            ]
        } else {
            // Normal colors
            command = [
                0xBC, 0x04, 0x06,
                UInt8(hue / 255), UInt8(hue % 255),
                0x03, 0xE8,  // Brightness 1000 = 0x03E8
                0x00, 0x00,
                red, green, blue,
                0x55
            ]
        }
        
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("🌟 STARLIGHT RGB(\(red),\(green),\(blue)): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// STARLIGHT Power Control
    func starlightPower(on: Bool) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        // Note: APK has reversed logic - 0=ON, 1=OFF
        let command: [UInt8] = [0xBC, 0x01, 0x01, on ? 0x01 : 0x00, 0x55]
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("🌟 STARLIGHT Power \(on ? "ON" : "OFF"): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// STARLIGHT Brightness Control
    func starlightBrightness(_ brightness: Int) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        let bright = min(max(brightness, 0), 1000)
        let command: [UInt8] = [
            0xBC, 0x05, 0x06,
            UInt8(bright / 256), UInt8(bright % 256),
            0x00, 0x00, 0x00, 0x00,
            0x55
        ]
        
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("� STARLIGHT Brightness \(bright): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// STARLIGHT Animation Mode
    func starlightMode(_ mode: Int) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        var modeIndex = mode
        // APK special case
        if modeIndex == 112 {
            modeIndex = 113
        } else if modeIndex >= 113 {
            modeIndex += 2
        }
        
        let command: [UInt8] = [
            0xBC, 0x06, 0x02,
            UInt8(modeIndex / 255), UInt8(modeIndex % 255),
            0x55
        ]
        
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("🌟 STARLIGHT Mode \(mode): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// STARLIGHT Animation Speed
    func starlightSpeed(_ speed: Int) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        let speedValue = min(max(speed, 0), 255)
        let command: [UInt8] = [0xBC, 0x08, 0x01, UInt8(speedValue), 0x55]
        
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("🌟 STARLIGHT Speed \(speedValue): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// STARLIGHT Animation Direction
    func starlightDirection(reverse: Bool) {
        guard let device = connectedDevice, let writeChar = ledControlCharacteristic else {
            print("❌ STARLIGHT: No device or characteristic")
            return
        }
        
        let command: [UInt8] = [0xBC, 0x07, 0x01, reverse ? 0x01 : 0x00, 0x55]
        
        let data = Data(command)
        device.writeValue(data, for: writeChar, type: .withoutResponse)
        print("🌟 STARLIGHT Direction \(reverse ? "Reverse" : "Normal"): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// RGB to HSV conversion
    private func rgbToHSV(r: UInt8, g: UInt8, b: UInt8) -> (hue: Int, sat: Int, val: Int) {
        let rNorm = Double(r) / 255.0
        let gNorm = Double(g) / 255.0
        let bNorm = Double(b) / 255.0
        
        let maxC = max(rNorm, gNorm, bNorm)
        let minC = min(rNorm, gNorm, bNorm)
        let delta = maxC - minC
        
        var hue: Double = 0
        if delta != 0 {
            if maxC == rNorm {
                hue = 60 * (((gNorm - bNorm) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == gNorm {
                hue = 60 * (((bNorm - rNorm) / delta) + 2)
            } else {
                hue = 60 * (((rNorm - gNorm) / delta) + 4)
            }
        }
        if hue < 0 { hue += 360 }
        
        let sat = maxC == 0 ? 0 : (delta / maxC)
        let val = maxC
        
        return (Int(hue), Int(sat * 1000), Int(val * 1000))
    }
    
    /// Test a specific characteristic with common LED commands
    private func testCharacteristic(_ char: CBCharacteristic, on device: CBPeripheral, serviceIndex: Int, charIndex: Int) {
        let testCommands: [(String, [UInt8])] = [
            ("Power ON", [0x01]),
            ("Power OFF", [0x00]),
            ("RED", [0xFF, 0x00, 0x00]),
            ("GREEN", [0x00, 0xFF, 0x00]),
            ("BLUE", [0x00, 0x00, 0xFF]),
            ("WHITE", [0xFF, 0xFF, 0xFF]),
            ("Simple ON", [0xCC, 0x23, 0x33]),
            ("Simple OFF", [0xCC, 0x24, 0x33])
        ]
        
        print("         🧪 Testing S\(serviceIndex)C\(charIndex) (\(char.uuid.uuidString)):")
        
        for (name, bytes) in testCommands {
            let data = Data(bytes)
            let writeType: CBCharacteristicWriteType = char.properties.contains(.write) ? .withResponse : .withoutResponse
            
            device.writeValue(data, for: char, type: writeType)
            print("            📤 \(name): \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
            usleep(1000000) // 1 second between tests
        }
    }

    /// Raw RGB data command (Most LED controllers)
    func sendRawRGBCommand(red: UInt8, green: UInt8, blue: UInt8) {
        guard let characteristic = ledControlCharacteristic else {
            print("❌ Raw RGB Command failed: No ledControlCharacteristic available")
            return
        }
        
        // Format 1: Simple 3-byte RGB
        let format1 = Data([red, green, blue])
        connectedDevice?.writeValue(format1, for: characteristic, type: .withResponse)
        print("📤 Raw RGB Format 1 (RGB): \(format1.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Format 2: 4-byte RGBA (with full alpha)
        let format2 = Data([red, green, blue, 0xFF])
        connectedDevice?.writeValue(format2, for: characteristic, type: .withResponse)
        print("📤 Raw RGB Format 2 (RGBA): \(format2.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Format 3: Command byte + RGB
        let format3 = Data([0x01, red, green, blue])
        connectedDevice?.writeValue(format3, for: characteristic, type: .withResponse)
        print("📤 Raw RGB Format 3 (CMD+RGB): \(format3.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// Universal LED Protocol Tests - Most common AppStore app formats
    func sendUniversalCommands(red: UInt8, green: UInt8, blue: UInt8) {
        guard let characteristic = ledControlCharacteristic else {
            print("❌ Universal commands failed: No characteristic")
            return
        }
        
        // 1. MagicHome/WiZ style: 0x31 + RGB + 0x00 + 0xF0 + 0x0F
        let magicHome = Data([0x31, red, green, blue, 0x00, 0xF0, 0x0F])
        connectedDevice?.writeValue(magicHome, for: characteristic, type: .withResponse)
        print("📤 MagicHome format: \(magicHome.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 2. Govee style: 0x33 + 0x01 + RGB + 0x00 + 0x00 + 0x00
        let govee = Data([0x33, 0x01, red, green, blue, 0x00, 0x00, 0x00])
        connectedDevice?.writeValue(govee, for: characteristic, type: .withResponse)
        print("📤 Govee format: \(govee.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 3. ELK-BLEDOM style: 0x7E + 0x00 + 0x03 + RGB + 0x00 + 0xEF
        let elkBledom = Data([0x7E, 0x00, 0x03, red, green, blue, 0x00, 0xEF])
        connectedDevice?.writeValue(elkBledom, for: characteristic, type: .withResponse)
        print("📤 ELK-BLEDOM format: \(elkBledom.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 4. LED BLE style: 0x56 + RGB + 0x00 + 0xF0 + 0xAA
        let ledBle = Data([0x56, red, green, blue, 0x00, 0xF0, 0xAA])
        connectedDevice?.writeValue(ledBle, for: characteristic, type: .withResponse)
        print("📤 LED BLE format: \(ledBle.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 5. HappyLighting style: 0x51 + RGB + 0x00 + checksum
        let checksum = (0x51 + Int(red) + Int(green) + Int(blue)) & 0xFF
        let happyLighting = Data([0x51, red, green, blue, 0x00, UInt8(checksum)])
        connectedDevice?.writeValue(happyLighting, for: characteristic, type: .withResponse)
        print("📤 HappyLighting format: \(happyLighting.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 6. Generic BLE Light: 0xCC + RGB + 0x33
        let genericBle = Data([0xCC, red, green, blue, 0x33])
        connectedDevice?.writeValue(genericBle, for: characteristic, type: .withResponse)
        print("📤 Generic BLE format: \(genericBle.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 7. WLED Binary: 0x01 + 0x00 + 0x00 + RGB
        let wledBinary = Data([0x01, 0x00, 0x00, red, green, blue])
        connectedDevice?.writeValue(wledBinary, for: characteristic, type: .withResponse)
        print("📤 WLED Binary format: \(wledBinary.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // 8. Triones/iLight style: 0x56 + RGB + 0x00 + 0xF0 + 0xAA
        let triones = Data([0x56, red, green, blue, 0x00, 0xF0, 0xAA])
        connectedDevice?.writeValue(triones, for: characteristic, type: .withResponse)
        print("📤 Triones format: \(triones.map { String(format: "%02X", $0) }.joined(separator: " "))")
    }
    
    /// BLE structured data commands (Android-BLE-LED protokolü)
    func sendBLEColorCommand(start: Int = 0, length: Int, red: Int, green: Int, blue: Int, alpha: Int = 255, brightness: Int = 255) {
        guard let characteristic = colorCharacteristic else { 
            print("❌ BLE Color Command failed: No colorCharacteristic available")
            return 
        }
        
        var data = Data()
        // NeoPixelColor protocol based on analyzed Android app
        data.append(contentsOf: withUnsafeBytes(of: UInt16(start).bigEndian) { Array($0) })
        data.append(contentsOf: withUnsafeBytes(of: UInt16(length).bigEndian) { Array($0) })
        data.append(UInt8(red))
        data.append(UInt8(green))
        data.append(UInt8(blue))
        data.append(UInt8(alpha))
        data.append(UInt8(brightness))
        
        print("📤 BLE Color Command: start:\(start) len:\(length) R:\(red) G:\(green) B:\(blue) A:\(alpha) Br:\(brightness)")
        print("   Raw data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        connectedDevice?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// Animation command (BLE protocol)
    func sendAnimationCommand(mode: AnimationMode, speed: Int = 50, reverse: Bool = false, delay: Int = 10) {
        guard let characteristic = ledControlCharacteristic else { return }
        
        var data = Data()
        data.append(UInt8(mode.rawValue))  // Mode
        data.append(UInt8(reverse ? 1 : 0)) // Reverse flag
        data.append(UInt8(delay))           // Delay
        
        // Mode-specific data
        switch mode {
        case .wheel:
            data.append(UInt8(speed))
        case .fade(let color1, let color2, let length):
            data.append(UInt8(speed))
            data.append(UInt8(length))
            data.append(contentsOf: colorToBytes(color1))
            data.append(contentsOf: colorToBytes(color2))
        case .chase(let color1, let color2, let length):
            data.append(UInt8(speed))
            data.append(UInt8(length))
            data.append(contentsOf: colorToBytes(color1))
            data.append(contentsOf: colorToBytes(color2))
        case .scan:
            data.append(UInt8(speed))
        case .none:
            break
        }
        
        connectedDevice?.writeValue(data, for: characteristic, type: .withResponse)
    }
    
    /// WLED-style JSON command
    func sendWLEDCommand(_ json: [String: Any]) {
        guard let characteristic = ledControlCharacteristic else {
            print("❌ WLED Command failed: No ledControlCharacteristic available")
            return
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            print("❌ WLED Command failed: Could not serialize JSON")
            return
        }
        
        if let jsonString = String(data: jsonData, encoding: .utf8) {
            print("📤 WLED Command: \(jsonString)")
        }
        
        connectedDevice?.writeValue(jsonData, for: characteristic, type: .withResponse)
    }
    
    // MARK: - Helper Methods
    private func colorToBytes(_ color: UInt32) -> [UInt8] {
        return [
            UInt8((color >> 24) & 0xFF), // Alpha or Red
            UInt8((color >> 16) & 0xFF), // Red or Green  
            UInt8((color >> 8) & 0xFF),  // Green or Blue
            UInt8(color & 0xFF)          // Blue or Alpha
        ]
    }
}

// MARK: - Animation Mode Enum
enum AnimationMode: CaseIterable {
    case none
    case wheel
    case fade(UInt32, UInt32, Int)
    case chase(UInt32, UInt32, Int)
    case scan
    
    var rawValue: Int {
        switch self {
        case .none: return 0
        case .wheel: return 1
        case .fade: return 2
        case .chase: return 3
        case .scan: return 4
        }
    }
    
    static var allCases: [AnimationMode] {
        return [.none, .wheel, .fade(0xFF0000, 0x0000FF, 10), .chase(0xFF0000, 0x0000FF, 5), .scan]
    }
    
    var displayName: String {
        switch self {
        case .none: return "Kapalı"
        case .wheel: return "Renk Çarkı"
        case .fade: return "Soldurma"
        case .chase: return "Kovalama"
        case .scan: return "Tarama"
        }
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        isBluetoothOn = central.state == .poweredOn
        
        switch central.state {
        case .poweredOn:
            connectionStatus = "Bluetooth Hazır"
        case .poweredOff:
            connectionStatus = "Bluetooth Kapalı"
        case .resetting:
            connectionStatus = "Bluetooth Yeniden Başlatılıyor"
        case .unauthorized:
            connectionStatus = "Bluetooth İzni Gerekli"
        case .unsupported:
            connectionStatus = "Bluetooth Desteklenmiyor"
        case .unknown:
            connectionStatus = "Bluetooth Durumu Bilinmiyor"
        @unknown default:
            connectionStatus = "Bilinmeyen Durum"
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // LED kontrolcüsü olabilecek cihazları filtrele
        let deviceName = peripheral.name ?? "Bilinmeyen"
        let lowercaseName = deviceName.lowercased()
        
        // Potansiyel LED controller isimleri
        let ledKeywords = ["led", "rgb", "argb", "neopixel", "ws2812", "wled", "esp32", "arduino", "strip", "light"]
        
        if ledKeywords.contains(where: { lowercaseName.contains($0) }) || peripheral.name != nil {
            if !discoveredDevices.contains(where: { $0.identifier == peripheral.identifier }) {
                discoveredDevices.append(peripheral)
                print("🔍 Bulunan cihaz: \(deviceName) (RSSI: \(RSSI))")
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        connectedDevice = peripheral
        isConnected = true
        connectionStatus = "Bağlandı: \(peripheral.name ?? "Bilinmeyen Cihaz")"
        
        peripheral.delegate = self
        peripheral.discoverServices(nil) // Tüm servisleri keşfet
        
        print("✅ Bağlantı kuruldu: \(peripheral.name ?? "Bilinmeyen")")
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        connectionStatus = "Bağlantı Hatası: \(error?.localizedDescription ?? "Bilinmeyen hata")"
        isConnected = false
        connectedDevice = nil
        
        print("❌ Bağlantı hatası: \(error?.localizedDescription ?? "Bilinmeyen")")
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectedDevice = nil
        ledControlCharacteristic = nil
        colorCharacteristic = nil
        stripConfigCharacteristic = nil
        
        if let error = error {
            connectionStatus = "Bağlantı Kesildi: \(error.localizedDescription)"
        } else {
            connectionStatus = "Bağlantı Kesildi"
        }
        
        print("🔌 Bağlantı kesildi: \(peripheral.name ?? "Bilinmeyen")")
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        print("🔍 Bulunan servisler:")
        for service in services {
            print("  - \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        print("🔍 Servis \(service.uuid) karakteristikleri:")
        
        for characteristic in characteristics {
            print("  - \(characteristic.uuid) [Properties: \(characteristic.properties)]")
            
            // Karakteristikleri tanıma ve atama
            switch characteristic.uuid {
            case CharacteristicUUIDs.neopixelColor:
                colorCharacteristic = characteristic
                print("    ✅ NeoPixel Color karakteristiği bulundu")
                
            case CharacteristicUUIDs.neopixelAnima:
                ledControlCharacteristic = characteristic
                print("    ✅ NeoPixel Animation karakteristiği bulundu")
                
            case CharacteristicUUIDs.neopixelStrip:
                stripConfigCharacteristic = characteristic
                print("    ✅ NeoPixel Strip karakteristiği bulundu")
                
            case CharacteristicUUIDs.genericWrite:
                // Generic write karakteristiği - ESP32 tarzı string komutlar için
                if ledControlCharacteristic == nil {
                    ledControlCharacteristic = characteristic
                    print("    ✅ Generic Write karakteristiği bulundu")
                }
                
            default:
                // FFF3 ve FFF4 karakteristiklerini kontrol et (Chinese LED controllers)
                if characteristic.uuid.uuidString == "FFF3" {
                    writeCharacteristic = characteristic
                    ledControlCharacteristic = characteristic
                    print("    ✅ FFF3 Write karakteristiği bulundu")
                } else if characteristic.uuid.uuidString == "FFF4" {
                    print("    ✅ FFF4 Notify karakteristiği bulundu")
                }
                
                // Yazılabilir karakteristikleri genel kontrol için kullan
                else if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                    if ledControlCharacteristic == nil {
                        ledControlCharacteristic = characteristic
                        writeCharacteristic = characteristic
                        print("    ✅ Yazılabilir karakteristik bulundu ve kontrol için ayarlandı")
                    }
                }
            }
            
            // Notification'ları etkinleştir (varsa)
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Bağlantı durumunu güncelle
        if ledControlCharacteristic != nil || colorCharacteristic != nil {
            connectionStatus = "✅ Hazır - LED Kontrol Edilebilir"
            
            // CRITICAL DEBUG: Print all device info immediately
            print(String(repeating: "=", count: 50))
            print("🔍 STARLIGHT DEVICE ANALYSIS")
            print("📱 Device: \(peripheral.name ?? "Unknown")")
            print("🆔 ID: \(peripheral.identifier)")
            print("📊 State: \(peripheral.state.rawValue)")
            
            // Print ALL services and characteristics
            for service in peripheral.services ?? [] {
                print("🔧 Service: \(service.uuid)")
                for char in service.characteristics ?? [] {
                    let props = char.properties
                    print("   📝 \(char.uuid): Write=\(props.contains(.write)) WriteNoResp=\(props.contains(.writeWithoutResponse)) Read=\(props.contains(.read)) Notify=\(props.contains(.notify))")
                }
            }
            
            // Test with ONE simple command immediately
            print("🧪 IMMEDIATE TEST: Sending simple RED to ALL writable characteristics")
            for service in peripheral.services ?? [] {
                for char in service.characteristics ?? [] {
                    if char.properties.contains(.write) || char.properties.contains(.writeWithoutResponse) {
                        let simpleRed = Data([0xFF, 0x00, 0x00])
                        peripheral.writeValue(simpleRed, for: char, type: .withoutResponse)
                        print("📤 Sent FF0000 to \(char.uuid)")
                        usleep(500000) // 500ms wait
                    }
                }
            }
            print(String(repeating: "=", count: 50))
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("❌ Yazma hatası: \(error.localizedDescription)")
        } else {
            print("✅ Komut gönderildi: \(characteristic.uuid)")
        }
    }
    
    /// Test all available characteristics for STARLIGHT compatibility
    func testAllCharacteristicsForSTARLIGHT() {
        guard let device = connectedDevice else {
            print("❌ No connected device for testing")
            return
        }
        
        print("🔬 Testing ALL characteristics for STARLIGHT protocol compatibility...")
        print("📋 Device: \(device.name ?? "Unknown") - \(device.identifier)")
        
        // Get all services and their characteristics
        for service in device.services ?? [] {
            print("🔍 Service: \(service.uuid)")
            for characteristic in service.characteristics ?? [] {
                let props = characteristic.properties
                print("   📝 Char: \(characteristic.uuid) - Write:\(props.contains(.write)) WriteNoResp:\(props.contains(.writeWithoutResponse)) Read:\(props.contains(.read)) Notify:\(props.contains(.notify))")
                
                if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                    print("🧪 Testing characteristic: \(characteristic.uuid) with RED command...")
                    
                    // Test multiple simple protocols on this characteristic
                    let testCommands: [(String, Data)] = [
                        ("Simple RGB", Data([0xFF, 0x00, 0x00])),
                        ("WRGB", Data([0x00, 0xFF, 0x00, 0x00])),
                        ("0xFF Prefix", Data([0xFF, 0xFF, 0x00, 0x00])),
                        ("ELK-BLEDOM", Data([0x7e, 0x00, 0x05, 0x03, 0xFF, 0x00, 0x00, 0x00, 0xef])),
                        ("Triones", Data([0x56, 0xFF, 0x00, 0x00, 0x00, 0xf0, 0xaa])),
                        ("Magic Blue", Data([0xFF, 0x00, 0x00, 0x00, 0xf0, 0x0f])),
                        ("Power ON", Data([0xCC, 0x23, 0x33])),
                        ("Simple Power", Data([0x01])),
                        ("Zero Bytes", Data([0x00, 0x00, 0x00]))
                    ]
                    
                    for (name, command) in testCommands {
                        device.writeValue(command, for: characteristic, type: .withoutResponse)
                        print("📤 \(characteristic.uuid) -> \(name): \(command.map { String(format: "%02X", $0) }.joined(separator: " "))")
                        usleep(300000) // 300ms wait
                    }
                    
                    print("⏳ Tested \(testCommands.count) commands on \(characteristic.uuid)")
                }
            }
        }
        
        print("✅ Finished testing all characteristics. Check LED for any color changes!")
    }
    func sendChineseColorCommands(red: UInt8, green: UInt8, blue: UInt8) {
        guard let device = connectedDevice, let char = writeCharacteristic else {
            print("❌ No device or write characteristic")
            return
        }
        
        print("🇨🇳 Testing Chinese LED protocols one by one - R:\(red) G:\(green) B:\(blue)")
        
        // Test only one protocol at a time to avoid crashes
        // Protocol 1: HappyLighting format (most common Chinese app)
        let happyLighting = Data([0x7E, 0x00, 0x03, red, green, blue, 0x00, 0xEF])
        device.writeValue(happyLighting, for: char, type: .withoutResponse)
        print("📤 HappyLighting: \(happyLighting.map { String(format: "%02X", $0) }.joined(separator: " "))")
        
        // Wait and try next protocol
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Protocol 2: LED Shop format 
            let ledShop = Data([0x7E, 0x04, 0x01, red, green, blue, 0x00, 0xEF])
            device.writeValue(ledShop, for: char, type: .withoutResponse)
            print("📤 LED Shop: \(ledShop.map { String(format: "%02X", $0) }.joined(separator: " "))")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                // Protocol 3: Simple RGB (most basic)
                let simpleRGB = Data([red, green, blue])
                device.writeValue(simpleRGB, for: char, type: .withoutResponse)
                print("📤 Simple RGB: \(simpleRGB.map { String(format: "%02X", $0) }.joined(separator: " "))")
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { 
            print("📨 Empty response from \(characteristic.uuid)")
            return 
        }
        
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        print("📨 Response from \(characteristic.uuid): \(hexString) (length: \(data.count))")
        
        // Try to interpret the response
        if data.count > 0 {
            let firstByte = data[0]
            switch firstByte {
            case 0x7E:
                print("  🔍 Protocol response detected (starts with 7E)")
            case 0x00:
                print("  🔍 Status response (starts with 00)")
            case 0xFF:
                print("  🔍 Error response (starts with FF)")
            default:
                print("  🔍 Unknown response format")
            }
        }
    }
}