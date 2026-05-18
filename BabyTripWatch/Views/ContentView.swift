//
//  ContentView.swift
//  BabyTripWatch
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = WatchViewModel()
    
    var body: some View {
        VStack {
            if userSettings.hasProfile() {
                if viewModel.isLoading {
                    ProgressView()
                        .controlSize(.large)
                } else if let result = viewModel.evaluationResult {
                    ScrollView {
                        VStack(spacing: 12) {
                            Text(result.riskLevel.description)
                                .font(.title)
                                .foregroundColor(colorForRiskLevel(result.riskLevel))
                            
                            Text("得分: \(result.overallScore)/100")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Divider()
                            
                            ForEach(result.factorScores) { factor in
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(factor.factor.displayName)
                                        Spacer()
                                        Text("\(factor.score)")
                                    }
                                    .font(.caption)
                                    
                                    ProgressView(value: Double(factor.score) / 100)
                                        .tint(colorForScore(factor.score))
                                }
                            }
                            
                            Divider()
                            
                            Text(result.recommendation)
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                        }
                        .padding()
                    }
                    .refreshable {
                        await refreshData()
                    }
                } else if let error = viewModel.errorMessage {
                    VStack(spacing: 8) {
                        Text("出错了")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("重试") {
                            Task {
                                await refreshData()
                            }
                        }
                    }
                } else {
                    Text("正在加载...")
                        .foregroundColor(.secondary)
                }
            } else {
                Text("请先在 iPhone 上完成设置")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .navigationTitle("宝宝出行")
        .onAppear {
            Task {
                await refreshData()
            }
        }
    }
    
    private func refreshData() async {
        guard let baby = userSettings.babyProfile,
              let location = locationManager.location else {
            return
        }
        
        await viewModel.loadWeatherAndEvaluate(location: location, baby: baby)
    }
    
    private func colorForRiskLevel(_ level: RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
    
    private func colorForScore(_ score: Int) -> Color {
        if score >= 70 {
            return .green
        } else if score >= 40 {
            return .orange
        } else {
            return .red
        }
    }
}

class WatchViewModel: ObservableObject {
    @Published var evaluationResult: EvaluationResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let weatherAPIClient = WeatherAPIClient()
    private let riskEvaluator = RiskEvaluator()
    
    func loadWeatherAndEvaluate(location: CLLocation, baby: BabyProfile) async {
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            let weather = try await weatherAPIClient.fetchWeather(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            
            let result = riskEvaluator.evaluate(baby: baby, weather: weather)
            
            DispatchQueue.main.async {
                self.evaluationResult = result
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ContentView()
                .environmentObject(UserSettings.shared)
        }
    }
}
