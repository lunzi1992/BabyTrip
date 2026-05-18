//
//  UserPreferences.swift
//  BabyTripShared
//
//  V3: 用户个性化偏好设置
//

import Foundation

/// 用户个性化偏好设置
public struct UserPreferences: Codable, Equatable {
    
    // MARK: - 外出偏好
    
    /// 偏好外出时间段
    public var preferredOutingTimes: [OutingTimePreference]
    
    /// 单次外出时长偏好（分钟）
    public var preferredOutingDuration: Int
    
    /// 最小外出温度阈值
    public var minOutingTemperature: Double
    
    /// 最大外出温度阈值
    public var maxOutingTemperature: Double
    
    /// 最大可接受紫外线指数
    public var maxAcceptableUV: Double
    
    /// 最大可接受风速 (km/h)
    public var maxAcceptableWindSpeed: Double
    
    /// 最大可接受 AQI
    public var maxAcceptableAQI: Int
    
    // MARK: - 提醒设置
    
    /// 启用天气变化提醒
    public var enableWeatherAlerts: Bool
    
    /// 提醒间隔（分钟）
    public var alertInterval: Int
    
    /// 仅在适合外出时提醒
    public var alertOnlyWhenSuitable: Bool
    
    // MARK: - 显示设置
    
    /// 显示体感温度（优先于实际温度）
    public var prioritizeFeelsLike: Bool
    
    /// 显示详细风险分析
    public var showDetailedAnalysis: Bool
    
    /// 温度单位 (celsius/fahrenheit)
    public var temperatureUnit: TemperatureUnit
    
    // MARK: - 初始化
    
    public init(
        preferredOutingTimes: [OutingTimePreference] = OutingTimePreference.defaultTimes,
        preferredOutingDuration: Int = 60,
        minOutingTemperature: Double = 10.0,
        maxOutingTemperature: Double = 30.0,
        maxAcceptableUV: Double = 5.0,
        maxAcceptableWindSpeed: Double = 15.0,
        maxAcceptableAQI: Int = 100,
        enableWeatherAlerts: Bool = true,
        alertInterval: Int = 30,
        alertOnlyWhenSuitable: Bool = false,
        prioritizeFeelsLike: Bool = true,
        showDetailedAnalysis: Bool = true,
        temperatureUnit: TemperatureUnit = .celsius
    ) {
        self.preferredOutingTimes = preferredOutingTimes
        self.preferredOutingDuration = preferredOutingDuration
        self.minOutingTemperature = minOutingTemperature
        self.maxOutingTemperature = maxOutingTemperature
        self.maxAcceptableUV = maxAcceptableUV
        self.maxAcceptableWindSpeed = maxAcceptableWindSpeed
        self.maxAcceptableAQI = maxAcceptableAQI
        self.enableWeatherAlerts = enableWeatherAlerts
        self.alertInterval = alertInterval
        self.alertOnlyWhenSuitable = alertOnlyWhenSuitable
        self.prioritizeFeelsLike = prioritizeFeelsLike
        self.showDetailedAnalysis = showDetailedAnalysis
        self.temperatureUnit = temperatureUnit
    }
}

// MARK: - 外出时间偏好

public struct OutingTimePreference: Codable, Equatable, Identifiable {
    public let id = UUID()
    public var startHour: Int      // 0-23
    public var endHour: Int        // 0-23
    public var isEnabled: Bool
    public var label: String       // 如"早晨", "下午"
    
    public init(startHour: Int, endHour: Int, isEnabled: Bool = true, label: String = "") {
        self.startHour = startHour
        self.endHour = endHour
        self.isEnabled = isEnabled
        self.label = label
    }
    
    /// 默认外出时间段
    public static var defaultTimes: [OutingTimePreference] {
        return [
            OutingTimePreference(startHour: 9, endHour: 11, label: "上午"),
            OutingTimePreference(startHour: 16, endHour: 18, label: "傍晚")
        ]
    }
    
    /// 格式化时间段显示
    public var formattedTimeRange: String {
        return String(format: "%02d:00 - %02d:00", startHour, endHour)
    }
}

// MARK: - 温度单位

public enum TemperatureUnit: String, Codable {
    case celsius = "celsius"
    case fahrenheit = "fahrenheit"
    
    public var symbol: String {
        switch self {
        case .celsius: return "°C"
        case .fahrenheit: return "°F"
        }
    }
    
    public func convert(_ celsius: Double) -> Double {
        switch self {
        case .celsius:
            return celsius
        case .fahrenheit:
            return celsius * 9 / 5 + 32
        }
    }
}

// MARK: - 个性化建议生成

public extension UserPreferences {
    
    /// 根据用户偏好生成个性化建议
    func generatePersonalizedAdvice(weather: WeatherData, baseRecommendations: [String]) -> [String] {
        var personalized = baseRecommendations
        
        // 1. 检查温度偏好
        if weather.temperature < minOutingTemperature {
            personalized.append("当前温度低于您设定的偏好 (\(Int(minOutingTemperature))°C)")
        } else if weather.temperature > maxOutingTemperature {
            personalized.append("当前温度高于您设定的偏好 (\(Int(maxOutingTemperature))°C)")
        }
        
        // 2. 检查紫外线偏好
        if weather.uvIndex > maxAcceptableUV {
            personalized.append("紫外线强度超过您设定的接受范围")
        }
        
        // 3. 检查风速偏好
        if weather.windSpeed > maxAcceptableWindSpeed {
            personalized.append("风速超过您设定的接受范围")
        }
        
        // 4. 检查空气质量偏好
        if weather.aqi > maxAcceptableAQI {
            personalized.append("空气质量低于您设定的标准")
        }
        
        // 5. 根据偏好外出时间段给出建议
        let currentHour = Calendar.current.component(.hour, from: Date())
        let isInPreferredTime = preferredOutingTimes
            .filter { $0.isEnabled }
            .contains { currentHour >= $0.startHour && currentHour < $0.endHour }
        
        if !isInPreferredTime && !preferredOutingTimes.filter({ $0.isEnabled }).isEmpty {
            if let nextPreferred = preferredOutingTimes
                .filter({ $0.isEnabled && $0.startHour > currentHour })
                .min(by: { $0.startHour < $1.startHour }) {
                personalized.append("您偏好的外出时间段是 \(nextPreferred.label) (\(nextPreferred.formattedTimeRange))")
            }
        }
        
        return personalized
    }
    
    /// 检查天气是否符合用户偏好
    func matchesPreferences(weather: WeatherData) -> PreferenceMatch {
        var mismatches: [String] = []
        
        if weather.temperature < minOutingTemperature {
            mismatches.append("温度过低")
        } else if weather.temperature > maxOutingTemperature {
            mismatches.append("温度过高")
        }
        
        if weather.uvIndex > maxAcceptableUV {
            mismatches.append("紫外线过强")
        }
        
        if weather.windSpeed > maxAcceptableWindSpeed {
            mismatches.append("风速过大")
        }
        
        if weather.aqi > maxAcceptableAQI {
            mismatches.append("空气质量不佳")
        }
        
        return PreferenceMatch(
            isMatch: mismatches.isEmpty,
            mismatches: mismatches
        )
    }
}

/// 偏好匹配结果
public struct PreferenceMatch {
    public let isMatch: Bool
    public let mismatches: [String]
}
