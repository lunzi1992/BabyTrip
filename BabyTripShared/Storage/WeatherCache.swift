//
//  WeatherCache.swift
//  BabyTripShared
//
//  V4: 天气数据缓存（15分钟有效期）和昨日数据对比
//

import Foundation

// MARK: - 缓存数据模型
public struct CachedWeatherData: Codable {
    public let weather: WeatherData
    public let hourly: [QWeatherHourlyV7]
    public let timestamp: Date
    public let location: String
    
    public var isValid: Bool {
        let fifteenMinutes: TimeInterval = 15 * 60
        return Date().timeIntervalSince(timestamp) < fifteenMinutes
    }
}

// MARK: - 历史天气记录（用于昨日对比）
public struct WeatherHistoryRecord: Codable {
    public let date: Date
    public let weather: WeatherData
    public let overallScore: Int
    
    public var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// MARK: - 天气缓存管理器
public class WeatherCacheManager {
    public static let shared = WeatherCacheManager()
    
    private let userDefaults = UserDefaults.standard
    private let cacheKey = "com.babytrip.weatherCache"
    private let historyKey = "com.babytrip.weatherHistory"
    
    private init() {}
    
    // MARK: - 当前数据缓存
    
    public func saveCache(weather: WeatherData, hourly: [QWeatherHourlyV7], location: String) {
        let cache = CachedWeatherData(
            weather: weather,
            hourly: hourly,
            timestamp: Date(),
            location: location
        )
        
        if let encoded = try? JSONEncoder().encode(cache) {
            userDefaults.set(encoded, forKey: cacheKey)
        }
        
        // 同时保存到历史记录
        saveToHistory(weather: weather)
    }
    
    public func loadCache() -> CachedWeatherData? {
        guard let data = userDefaults.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(CachedWeatherData.self, from: data) else {
            return nil
        }
        return cache
    }
    
    public func clearCache() {
        userDefaults.removeObject(forKey: cacheKey)
    }
    
    // MARK: - 历史记录（用于昨日对比）
    
    private func saveToHistory(weather: WeatherData) {
        let engine = TripRecommendationEngine()
        let score = engine.calculateOverallScore(weather: weather)
        
        let record = WeatherHistoryRecord(
            date: Date(),
            weather: weather,
            overallScore: score
        )
        
        var history = loadHistory()
        
        // 检查今天是否已有记录，有则更新，无则添加
        let todayString = record.dateString
        if let index = history.firstIndex(where: { $0.dateString == todayString }) {
            history[index] = record
        } else {
            history.append(record)
        }
        
        // 只保留最近30天记录
        if history.count > 30 {
            history.sort { $0.date < $1.date }
            history = Array(history.suffix(30))
        }
        
        if let encoded = try? JSONEncoder().encode(history) {
            userDefaults.set(encoded, forKey: historyKey)
        }
    }
    
    public func loadHistory() -> [WeatherHistoryRecord] {
        guard let data = userDefaults.data(forKey: historyKey),
              let history = try? JSONDecoder().decode([WeatherHistoryRecord].self, from: data) else {
            return []
        }
        return history
    }
    
    // MARK: - 昨日对比
    
    public func getYesterdayComparison() -> WeatherComparison? {
        let history = loadHistory()
        guard let today = history.last else { return nil }
        
        // 找昨天的记录
        let calendar = Calendar.current
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today.date) else { return nil }
        let yesterdayString = WeatherHistoryRecord(date: yesterday, weather: .empty, overallScore: 0).dateString
        
        guard let yesterdayRecord = history.first(where: { $0.dateString == yesterdayString }) else {
            return nil
        }
        
        return generateComparison(today: today, yesterday: yesterdayRecord)
    }
    
    private func generateComparison(today: WeatherHistoryRecord, yesterday: WeatherHistoryRecord) -> WeatherComparison {
        let engine = TripRecommendationEngine()
        
        let todayScore = today.overallScore
        let yesterdayScore = yesterday.overallScore
        
        var improvements: [String] = []
        var degradations: [String] = []
        
        let todayW = today.weather
        let yestW = yesterday.weather
        
        // 温度对比
        if todayW.feelsLike >= 18 && todayW.feelsLike <= 26 {
            if yestW.feelsLike < 18 || yestW.feelsLike > 26 {
                improvements.append("温度更舒适")
            }
        } else if yestW.feelsLike >= 18 && yestW.feelsLike <= 26 {
            degradations.append("温度不如昨天舒适")
        }
        
        // AQI对比
        if todayW.aqi < yestW.aqi {
            improvements.append("空气质量更好")
        } else if todayW.aqi > yestW.aqi {
            degradations.append("空气质量不如昨天")
        }
        
        // 风速对比
        if todayW.windSpeed < yestW.windSpeed - 5 {
            improvements.append("风速更低")
        } else if todayW.windSpeed > yestW.windSpeed + 5 {
            degradations.append("风比昨天大")
        }
        
        // UV对比
        if todayW.uvIndex < yestW.uvIndex - 2 {
            improvements.append("紫外线更弱")
        } else if todayW.uvIndex > yestW.uvIndex + 2 {
            degradations.append("紫外线比昨天强")
        }
        
        // 如果没有具体项，给个总体评价
        if improvements.isEmpty && degradations.isEmpty {
            if todayScore > yesterdayScore {
                improvements.append("综合天气条件更好")
            } else if todayScore < yesterdayScore {
                degradations.append("综合天气条件不如昨天")
            } else {
                improvements.append("和昨天差不多")
            }
        }
        
        return WeatherComparison(
            todayScore: todayScore,
            yesterdayScore: yesterdayScore,
            isTodayBetter: todayScore >= yesterdayScore,
            improvements: improvements,
            degradations: degradations
        )
    }
}

// MARK: - 让 WeatherHistoryRecord 支持 dateString 计算
extension WeatherHistoryRecord {
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }
}
