//
//  HomeView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//  V2: 全新首页布局
//

import SwiftUI
import BabyTripShared
import CoreLocation

class HomeViewModel: ObservableObject {
    @Published var weatherData: WeatherData?
    @Published var evaluationResult: EvaluationResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var locationName: String?
    @Published var weatherAlert: WeatherAlert?     // V3: 天气提醒
    @Published var lastUpdateTime: Date?             // V3: 数据更新时间
    
    // V4: 新增属性
    @Published var recommendedTimeSlots: [RecommendedTimeSlot] = []
    @Published var clothingAdvice: ClothingAdvice?
    @Published var yesterdayComparison: WeatherComparison?
    
    private let weatherAPIClient = WeatherAPIClient()
    private let riskEvaluator = RiskEvaluator()
    private let weatherAlertManager = WeatherAlertManager.shared
    private let geocoder = CLGeocoder()
    
    // MARK: - 缓存
    private var cachedWeather: WeatherData?
    private var cachedResult: EvaluationResult?
    private var cachedLocation: CLLocation?
    private var lastFetchTime: Date?
    private let cacheDuration: TimeInterval = 15 * 60 // 15分钟
    
    // V3: 缓存配置
    public var cacheConfig: CacheConfiguration {
        return CacheConfiguration(
            duration: cacheDuration,
            lastUpdate: lastUpdateTime,
            isValid: isCacheValid
        )
    }
    
    public var isCacheValid: Bool {
        guard let lastTime = lastFetchTime else { return false }
        return Date().timeIntervalSince(lastTime) < cacheDuration
    }
    
    func loadWeatherAndEvaluate(location: CLLocation, baby: BabyProfile) async {
        // 检查缓存是否有效（15分钟内且位置变化小于1公里）
        if let cachedLoc = cachedLocation,
           let lastTime = lastFetchTime,
           Date().timeIntervalSince(lastTime) < cacheDuration,
           let weather = cachedWeather,
           let result = cachedResult {
            let distance = location.distance(from: cachedLoc)
            if distance < 1000 { // 1公里内使用缓存
                DispatchQueue.main.async {
                    self.weatherData = weather
                    self.evaluationResult = result
                    self.isLoading = false
                }
                return
            }
        }
        
        DispatchQueue.main.async {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // V4: 使用带缓存和推荐的新 API
            let result = try await weatherAPIClient.fetchWeatherWithCache(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                forceRefresh: false
            )
            
            let weather = result.weather
            let hourly = result.hourly
            let timeSlots = result.timeSlots
            let clothing = result.clothing
            
            // 2. 评估当前天气
            let evaluation = riskEvaluator.evaluate(baby: baby, weather: weather)
            
            // 3. 获取昨日对比
            let comparison = weatherAPIClient.getYesterdayComparison()
            
            // 4. 反向地理编码获取位置名称
            let placemark = try await geocoder.reverseGeocodeLocation(location)
            let locationName = placemark.first?.locality ?? placemark.first?.administrativeArea ?? "未知位置"
            
            // 5. 更新缓存
            self.cachedWeather = weather
            self.cachedResult = evaluation
            self.cachedLocation = location
            self.lastFetchTime = Date()
            
            // V3: 检查天气提醒
            if let alert = self.weatherAlertManager.checkWeatherChange(
                currentWeather: weather,
                babyAgeInMonths: baby.ageInMonths
            ) {
                DispatchQueue.main.async {
                    self.weatherAlert = alert
                }
            }
            
            DispatchQueue.main.async {
                self.weatherData = weather
                self.evaluationResult = evaluation
                self.recommendedTimeSlots = timeSlots
                self.clothingAdvice = clothing
                self.yesterdayComparison = comparison
                self.locationName = locationName
                self.lastUpdateTime = Date()
                self.isLoading = false
            }
        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    /// 手动清除缓存（下拉刷新时使用）
    func clearCache() {
        cachedWeather = nil
        cachedResult = nil
        cachedLocation = nil
        lastFetchTime = nil
        lastUpdateTime = nil
    }
}

// MARK: - V3: 缓存配置

struct CacheConfiguration {
    let duration: TimeInterval
    let lastUpdate: Date?
    let isValid: Bool
    
    var formattedUpdateTime: String {
        guard let lastUpdate = lastUpdate else { return "未更新" }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "更新于 \(formatter.string(from: lastUpdate))"
    }
}

struct HomeView: View {
    @EnvironmentObject var userSettings: UserSettings
    @EnvironmentObject var locationManager: LocationManager
    @StateObject var viewModel: HomeViewModel
    
    init(viewModel: HomeViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if viewModel.isLoading {
                    loadingView
                } else if let error = viewModel.errorMessage {
                    errorView(error)
                } else if let result = viewModel.evaluationResult, let weather = viewModel.weatherData {
                    v2ResultView(result, weather)
                } else {
                    emptyView
                }
            }
            .padding()            
        }
        .refreshable {
            viewModel.clearCache()
            refreshData()
        }
        .onAppear {
            if locationManager.location == nil {
                locationManager.requestLocation()
            }
            refreshData()
        }
        .onChange(of: locationManager.location) { _ in
            refreshData()
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func refreshData() {
        guard let baby = userSettings.babyProfile,
              let location = locationManager.location else {
            return
        }
        
        Task {
            await viewModel.loadWeatherAndEvaluate(location: location, baby: baby)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text("获取天气数据中...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text("获取数据失败")
                .font(.title2)
            Text(message)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("重试") {
                refreshData()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    // MARK: - V2 首页布局
    
    private func v2ResultView(_ result: EvaluationResult, _ weather: WeatherData) -> some View {
        VStack(spacing: 16) {
            // 1. 城市 + 当前时间 + 更新时间
            locationAndTimeView
            
            // V3: 天气提醒卡片
            if let alert = viewModel.weatherAlert {
                weatherAlertCard(alert)
            }
            
            // 2. 风险等级大标题
            riskLevelCard(result)
            
            // 3. 人话总结
            humanSummaryCard(result)
            
            // 4. 当前天气概览（移到总结下方）
            weatherOverviewCard(weather)
            
            // V4: 昨日对比卡片
            if let comparison = viewModel.yesterdayComparison {
                yesterdayComparisonCard(comparison)
            }
            
            // V4: 最佳外出时间推荐
            if !viewModel.recommendedTimeSlots.isEmpty {
                v4BestTimeCard(viewModel.recommendedTimeSlots)
            }
            
            // V4: 穿衣指南
            if let clothing = viewModel.clothingAdvice {
                clothingCard(clothing)
            }
            
            // 5. 原因列表
            reasonsCard(result)
            
            // 6. 行动建议
            recommendationsCard(result)
            
            // 7. 最佳外出时间（P1）
            if let bestTime = result.bestTimeRange {
                bestTimeCard(bestTime)
            }
            
            // 8. 宝宝信息卡片
            if let baby = userSettings.babyProfile {
                babyInfoCard(baby)
            }
            
            // 9. V3: 更新时间提示
            updateTimeView
            
            // 10. 免责声明
            disclaimerView
        }
    }
    
    private var locationAndTimeView: some View {
        HStack {
            Image(systemName: "location.fill")
                .foregroundColor(.blue)
                .font(.caption)
            Text(viewModel.locationName ?? "未知位置")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(currentTimeString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - V3: 天气提醒卡片
    
    private func weatherAlertCard(_ alert: WeatherAlert) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: alertIcon(for: alert.highestLevel))
                    .foregroundColor(alertColor(for: alert.highestLevel))
                    .font(.title3)
                Text(alert.notificationTitle)
                    .font(.headline)
                    .foregroundColor(alertColor(for: alert.highestLevel))
                Spacer()
                Button(action: {
                    viewModel.weatherAlert = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(alert.conditions) { condition in
                    HStack(alignment: .top, spacing: 6) {
                        Circle()
                            .fill(alertColor(for: condition.level))
                            .frame(width: 6, height: 6)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(condition.message)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(condition.recommendation)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(alertColor(for: alert.highestLevel).opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(alertColor(for: alert.highestLevel).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func alertIcon(for level: AlertLevel) -> String {
        switch level {
        case .danger:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "exclamationmark.circle.fill"
        case .caution:
            return "info.circle.fill"
        }
    }
    
    private func alertColor(for level: AlertLevel) -> Color {
        switch level {
        case .danger:
            return .red
        case .warning:
            return .orange
        case .caution:
            return .yellow
        }
    }
    
    // MARK: - V3: 更新时间视图
    
    private var updateTimeView: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundColor(.secondary)
                .font(.caption)
            Text(viewModel.cacheConfig.formattedUpdateTime)
                .font(.caption)
                .foregroundColor(.secondary)
            if viewModel.isCacheValid {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                    Text("缓存有效")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            Spacer()
        }
    }
    
    private var currentTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    private func riskLevelCard(_ result: EvaluationResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                riskLevelIcon(result.riskLevel)
                    .font(.system(size: 40))
                Text(riskLevelTitle(result.riskLevel))
                    .font(.system(size: 28, weight: .bold))
            }
            .foregroundColor(colorForRiskLevel(result.riskLevel))
            
            if result.overallScore > 0 {
                Text("风险指数: \(result.overallScore)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(colorForRiskLevel(result.riskLevel).opacity(0.1))
        )
    }
    
    private func riskLevelIcon(_ level: RiskLevel) -> some View {
        switch level {
        case .safe:
            return Image(systemName: "checkmark.circle.fill")
        case .caution:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .unsafe:
            return Image(systemName: "xmark.circle.fill")
        }
    }
    
    private func riskLevelTitle(_ level: RiskLevel) -> String {
        switch level {
        case .safe:
            return "适合外出"
        case .caution:
            return "谨慎外出"
        case .unsafe:
            return "不建议外出"
        }
    }
    
    private func humanSummaryCard(_ result: EvaluationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("一句话总结")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(result.humanSummary)
                .font(.body)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func reasonsCard(_ result: EvaluationResult) -> some View {
        let contributions = result.factorContributions.filter { $0.points > 0 }
        guard !contributions.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("主要原因")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(contributions.sorted { $0.points > $1.points }.prefix(3)) { contribution in
                        if let reason = contribution.reasons.first {
                            HStack(alignment: .top, spacing: 8) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(reason)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        )
    }
    
    private func recommendationsCard(_ result: EvaluationResult) -> some View {
        guard !result.recommendations.isEmpty else { return AnyView(EmptyView()) }
        
        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("建议")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(result.recommendations, id: \.self) { recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            Text(recommendation)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        )
    }
    
    private func bestTimeCard(_ timeRange: TimeRange) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日较适合外出时间")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock.fill")
                    .foregroundColor(.green)
                Text(formatTimeRange(timeRange))
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text(timeRange.reason)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func formatTimeRange(_ timeRange: TimeRange) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: timeRange.start)) - \(formatter.string(from: timeRange.end))"
    }
    
    private func babyInfoCard(_ baby: BabyProfile) -> some View {
        let ageMonths = baby.ageInMonths
        let stage = ageMonths <= 3 ? "新生儿" : (ageMonths <= 6 ? "小婴儿" : "婴儿")
        let sensitivity = ageMonths <= 3 ? "高敏感" : (ageMonths <= 6 ? "中高敏感" : "中等敏感")
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("宝宝信息")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "face.smiling.fill")
                    .foregroundColor(.pink)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(ageMonths)个月 · \(stage)阶段")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("(\(sensitivity))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func weatherOverviewCard(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("当前天气")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                // V3: 天气状况图标
                Image(systemName: weatherConditionIcon(weather.condition))
                    .font(.title2)
                    .foregroundColor(weatherConditionColor(weather.condition))
            }
            
            // V3: 天气状况标签
            Text(weather.condition)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                // V3: 优先体感温度（如果用户偏好）
                if userSettings.preferences.prioritizeFeelsLike {
                    weatherItemWithColor(
                        title: "体感温度",
                        value: "\(Int(weather.feelsLike))°C",
                        icon: "thermometer.sun",
                        color: temperatureColor(weather.feelsLike)
                    )
                    weatherItem(title: "实际温度", value: "\(Int(weather.temperature))°C", icon: "thermometer")
                } else {
                    weatherItemWithColor(
                        title: "温度",
                        value: "\(Int(weather.temperature))°C",
                        icon: "thermometer",
                        color: temperatureColor(weather.temperature)
                    )
                    weatherItem(title: "体感", value: "\(Int(weather.feelsLike))°C", icon: "thermometer.sun")
                }
                
                // V3: 紫外线带颜色指示
                weatherItemWithColor(
                    title: "紫外线",
                    value: "\(Int(weather.uvIndex))",
                    icon: "sun.max",
                    color: uvColor(weather.uvIndex)
                )
                
                // V3: AQI带颜色指示
                weatherItemWithColor(
                    title: "AQI",
                    value: "\(weather.aqi)",
                    icon: "wind",
                    color: aqiColor(weather.aqi)
                )
                
                weatherItem(title: "风速", value: "\(Int(weather.windSpeed)) km/h", icon: "wind")
                weatherItem(title: "湿度", value: "\(Int(weather.humidity))%", icon: "drop")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - V3: 天气图标和颜色函数
    
    private func weatherConditionIcon(_ condition: String) -> String {
        let lowercased = condition.lowercased()
        if lowercased.contains("晴") || lowercased.contains("sun") {
            return "sun.max.fill"
        } else if lowercased.contains("多云") || lowercased.contains("cloud") {
            return "cloud.sun.fill"
        } else if lowercased.contains("阴") || lowercased.contains("overcast") {
            return "cloud.fill"
        } else if lowercased.contains("雨") || lowercased.contains("rain") {
            return "cloud.rain.fill"
        } else if lowercased.contains("雪") || lowercased.contains("snow") {
            return "snowflake"
        } else if lowercased.contains("雾") || lowercased.contains("fog") || lowercased.contains("霾") {
            return "cloud.fog.fill"
        } else if lowercased.contains("雷") || lowercased.contains("thunder") {
            return "cloud.bolt.fill"
        }
        return "sun.max.fill"
    }
    
    private func weatherConditionColor(_ condition: String) -> Color {
        let lowercased = condition.lowercased()
        if lowercased.contains("晴") || lowercased.contains("sun") {
            return .orange
        } else if lowercased.contains("雨") || lowercased.contains("rain") {
            return .blue
        } else if lowercased.contains("雪") || lowercased.contains("snow") {
            return .cyan
        } else if lowercased.contains("雾") || lowercased.contains("fog") || lowercased.contains("霾") {
            return .gray
        } else if lowercased.contains("雷") || lowercased.contains("thunder") {
            return .purple
        }
        return .yellow
    }
    
    private func temperatureColor(_ temp: Double) -> Color {
        switch temp {
        case ..<5: return .blue
        case 5..<15: return .cyan
        case 15..<25: return .green
        case 25..<32: return .orange
        default: return .red
        }
    }
    
    private func uvColor(_ uv: Double) -> Color {
        switch uv {
        case ..<3: return .green
        case 3..<6: return .yellow
        case 6..<8: return .orange
        case 8..<11: return .red
        default: return .purple
        }
    }
    
    private func aqiColor(_ aqi: Int) -> Color {
        switch aqi {
        case ..<50: return .green
        case 50..<100: return .yellow
        case 100..<150: return .orange
        case 150..<200: return .red
        case 200..<300: return .purple
        default: return .red
        }
    }
    
    private func weatherItemWithColor(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            Spacer()
        }
    }
    
    private func weatherItem(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
    }
    
    private var disclaimerView: some View {
        Text("本建议仅供参考，不能替代专业医疗意见。如有疑虑，请咨询儿科医生。")
            .font(.caption2)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }
    
    // MARK: - 其他视图
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.circle")
                .font(.largeTitle)
                .foregroundColor(.blue)
            Text("正在获取位置...")
                .foregroundColor(.secondary)
            if let status = locationManager.authorizationStatus {
                if status == .denied || status == .restricted {
                    Text("需要位置权限才能获取天气，请在设置中开启")
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 100)
    }
    
    private func colorForRiskLevel(_ level: RiskLevel) -> Color {
        switch level {
        case .safe: return .green
        case .caution: return .orange
        case .unsafe: return .red
        }
    }
    
    // MARK: - V4: 最佳外出时间推荐卡片
    
    private func v4BestTimeCard(_ timeSlots: [RecommendedTimeSlot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundColor(.green)
                Text("最佳外出时间")
                    .font(.headline)
                Spacer()
            }
            
            VStack(spacing: 12) {
                ForEach(timeSlots.prefix(2)) { slot in
                    HStack(spacing: 8) {
                        Image(systemName: slot.isBest ? "crown.fill" : "checkmark.circle.fill")
                            .foregroundColor(slot.isBest ? .orange : .green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(slot.timeRangeString)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            if !slot.reasons.isEmpty {
                                Text("• " + slot.reasons.joined(separator: " • "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - V4: 穿衣指南卡片
    
    private func clothingCard(_ advice: ClothingAdvice) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tshirt.fill")
                    .foregroundColor(.blue)
                Text("宝宝穿衣建议")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("体感温度 \(Int(advice.feelsLike))°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(advice.fullAdvice)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if !advice.notes.isEmpty {
                    ForEach(advice.notes, id: \.self) { note in
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(note)
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - V4: 昨日对比卡片
    
    private func yesterdayComparisonCard(_ comparison: WeatherComparison) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundColor(comparison.isTodayBetter ? .green : .orange)
                Text("与昨天对比")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                if !comparison.improvements.isEmpty {
                    ForEach(comparison.improvements, id: \.self) { improvement in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            Text(improvement)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if !comparison.degradations.isEmpty {
                    ForEach(comparison.degradations, id: \.self) { degradation in
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(degradation)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                HStack {
                    Spacer()
                    Text(comparison.summaryText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(comparison.isTodayBetter ? .green : .primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            HomeView(viewModel: HomeViewModel())
                .environmentObject(UserSettings.shared)
        }
    }
}
