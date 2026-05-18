//
//  ContentView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

struct ContentView: View {
    @EnvironmentObject var userSettings: UserSettings
    @StateObject private var viewModel = HomeViewModel()
    
    var body: some View {
        NavigationStack {
            if userSettings.hasProfile() {
                HomeView(viewModel: viewModel)
                    .navigationTitle("宝宝出行助手")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            NavigationLink {
                                SettingsView()
                            } label: {
                                Image(systemName: "gear")
                            }
                        }
                    }
            } else {
                SetupProfileView()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(UserSettings.shared)
    }
}
