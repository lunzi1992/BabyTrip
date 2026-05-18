//
//  BabyTripWatchApp.swift
//  BabyTripWatch
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

@main
struct BabyTripWatchApp: App {
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
