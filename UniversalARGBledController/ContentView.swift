//
//  ContentView.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI
import CoreBluetooth

struct ContentView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    @EnvironmentObject var ledController: LEDController
    @EnvironmentObject var audioManager: AudioManager
    
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                            .font(.title2)
                        Text("ARGB Controller")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    
                    // Connection Status
                    HStack {
                        Circle()
                            .fill(bluetoothManager.isConnected ? .green : .red)
                            .frame(width: 8, height: 8)
                        
                        Text(bluetoothManager.connectionStatus)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                Divider()
                
                // Navigation Tabs
                VStack(alignment: .leading, spacing: 4) {
                    SidebarButton(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "Bağlantı",
                        isSelected: selectedTab == 0
                    ) {
                        selectedTab = 0
                    }
                    
                    SidebarButton(
                        icon: "paintpalette.fill",
                        title: "Renk Kontrolü",
                        isSelected: selectedTab == 1
                    ) {
                        selectedTab = 1
                    }
                    
                    SidebarButton(
                        icon: "sparkles",
                        title: "Efektler",
                        isSelected: selectedTab == 2
                    ) {
                        selectedTab = 2
                    }
                    
                    SidebarButton(
                        icon: "music.note",
                        title: "Müzik Sync",
                        isSelected: selectedTab == 3
                    ) {
                        selectedTab = 3
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Quick Actions
                VStack(spacing: 8) {
                    Divider()
                    
                    HStack(spacing: 8) {
                        Button(action: { ledController.turnOn() }) {
                            Label("Aç", systemImage: "lightbulb.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(action: { ledController.turnOff() }) {
                            Label("Kapat", systemImage: "power")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .frame(minWidth: 200, maxWidth: 250)
            .background(Color(NSColor.controlBackgroundColor))
            
            // Main Content
            Group {
                switch selectedTab {
                case 0:
                    BluetoothConnectionView()
                case 1: 
                    ColorPickerView()
                case 2:
                    EffectsView()
                case 3:
                    MusicSyncView()
                default:
                    BluetoothConnectionView()
                }
            }
            .frame(minWidth: 500)
        }
        .navigationTitle("")
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: {}) {
                    Image(systemName: "sidebar.left")
                }
            }
        }
        .onAppear {
            // Setup connections between managers
            ledController.setBluetoothManager(bluetoothManager)
            audioManager.setLEDController(ledController)
        }
    }
}

struct SidebarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 20)
                
                Text(title)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct BluetoothConnectionView: View {
    @EnvironmentObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 50))
                    .foregroundColor(.blue)
                
                Text("Bluetooth Bağlantısı")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("ARGB LED kontrolcünüzü bulun ve bağlanın")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Connection Status Card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: bluetoothManager.isConnected ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(bluetoothManager.isConnected ? .green : .orange)
                    
                    Text("Durum")
                        .font(.headline)
                }
                
                Text(bluetoothManager.connectionStatus)
                    .font(.body)
                
                if bluetoothManager.isConnected, let device = bluetoothManager.connectedDevice {
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bağlı Cihaz:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text(device.name ?? "Bilinmeyen Cihaz")
                            .font(.headline)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            if !bluetoothManager.isConnected {
                // Scan Controls
                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button(action: { bluetoothManager.startScanning() }) {
                            Label("Cihaz Ara", systemImage: "magnifyingglass")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!bluetoothManager.isBluetoothOn)
                        
                        Button(action: { bluetoothManager.stopScanning() }) {
                            Label("Aramayı Durdur", systemImage: "stop.fill")
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Device List
                    if !bluetoothManager.discoveredDevices.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bulunan Cihazlar")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(bluetoothManager.discoveredDevices, id: \.identifier) { device in
                                        DeviceRowView(device: device) {
                                            bluetoothManager.connect(to: device)
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 300)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button("Bağlantıyı Kes") {
                        bluetoothManager.disconnect()
                    }
                    .buttonStyle(.bordered)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button("🚨 EMERGENCY TEST 🚨") {
                                bluetoothManager.emergencyProtocolTest()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Button("Tam Test") {
                                bluetoothManager.testAllCharacteristicsForSTARLIGHT()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack(spacing: 8) {
                            Button("🌍 İNTERNET PROTOKOL TEST") {
                                bluetoothManager.comprehensiveProtocolTest()
                            }
                            .buttonStyle(.borderedProminent) 
                            .controlSize(.regular)
                            
                            Button("💥 BRUTE FORCE HEX TEST") {
                                bluetoothManager.reverseEngineerProtocol()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .foregroundColor(.white)
                            .background(Color.orange)
                            
                            Button("🔍 TÜM SERVİSLER") {
                                bluetoothManager.discoverAllServices()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .foregroundColor(.white)
                            .background(Color.purple)
                        }
                        
                        Divider()
                        
                        VStack(spacing: 8) {
                            Text("🌟 STARLIGHT PROTOKOL (ÇALIŞAN!)")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            HStack(spacing: 8) {
                                Button("🔴 Kırmızı") {
                                    bluetoothManager.starlightSetColor(red: 255, green: 0, blue: 0)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                                
                                Button("🟢 Yeşil") {
                                    bluetoothManager.starlightSetColor(red: 0, green: 255, blue: 0)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                
                                Button("🔵 Mavi") {
                                    bluetoothManager.starlightSetColor(red: 0, green: 0, blue: 255)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.blue)
                                
                                Button("⚪ Beyaz") {
                                    bluetoothManager.starlightSetColor(red: 255, green: 255, blue: 255)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.gray)
                            }
                            
                            HStack(spacing: 8) {
                                Button("💡 AÇ") {
                                    bluetoothManager.starlightPower(on: true)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                
                                Button("🌑 KAPAT") {
                                    bluetoothManager.starlightPower(on: false)
                                }
                                .buttonStyle(.bordered)
                                
                                Button("🌈 Mod 1") {
                                    bluetoothManager.starlightMode(1)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.purple)
                                
                                Button("⚡ Mod 35") {
                                    bluetoothManager.starlightMode(35)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.orange)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

struct DeviceRowView: View {
    let device: CBPeripheral
    let onConnect: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name ?? "Bilinmeyen Cihaz")
                    .font(.headline)
                
                Text(device.identifier.uuidString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let services = device.services {
                    Text("\(services.count) servis")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
            
            Spacer()
            
            Button("Bağlan") {
                onConnect()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
        .environmentObject(BluetoothManager())
        .environmentObject(LEDController())
        .environmentObject(AudioManager())
}