//
//  UniversalARGBledControllerApp.swift
//  UniversalARGBledController
//
//  Created by Development Team on 23/10/2025.
//

import SwiftUI

@main
struct UniversalARGBledControllerApp: App {
    @StateObject private var bluetoothManager = BluetoothManager()
    @StateObject private var ledController = LEDController()
    @StateObject private var audioManager = AudioManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(bluetoothManager)
                .environmentObject(ledController)
                .environmentObject(audioManager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 800, height: 600)
    }
}