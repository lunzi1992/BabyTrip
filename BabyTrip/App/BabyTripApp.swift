//
//  BabyTripApp.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

@main
struct BabyTripApp: App {
    @StateObject private var userSettings = UserSettings.shared
    @StateObject private var locationManager = LocationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(userSettings)
                .environmentObject(locationManager)
        }
    }
}
