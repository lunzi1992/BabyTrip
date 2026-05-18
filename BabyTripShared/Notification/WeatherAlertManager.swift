//
//  WeatherAlertManager.swift
//  BabyTripShared
//
//  V3: 天气变化提醒管理器
//

import Foundation
import UserNotifications

/// 天气变化提醒管理器 - 监控天气数据变化并发送提醒
public class WeatherAlertManager: ObservableObject {
    
    public static let shared = WeatherAlertManager()
    
    @Published public var lastAlert: WeatherAlert?
    @Published public var isMonitoring = false
    
    private var previousWeather: WeatherData?
    private var alertThresholds: AlertThresholds
    
    /// 提醒阈值配置
    public struct AlertThresholds {
        public var maxTemperature: Double = 35.0      // 温度过高提醒 (°C)
        public var minTemperature: Double = 5.0       // 温度过低提醒 (°C)
        public var maxUVIndex: Double = 7.0           // 紫外线过强提醒
        public var maxAQI: Int = 150                  // 空气质量差提醒
        public var maxWindSpeed: Double = 20.0        // 风速过大提醒 (km/h)
        public var maxHumidity: Double = 85.0         // 湿度过高提醒
        public var minHumidity: Double = 20.0         // 湿度过低提醒
        
        public init() {}
    }
    
    private init() {
        self.alertThresholds = AlertThresholds()
        setupNotifications()
    }
    
    // MARK: - 通知权限
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                print("天气提醒通知权限已获取")
            }
        }
    }
    
    // MARK: - 天气监控
    
    /// 检查天气变化并发送提醒
    public func checkWeatherChange(currentWeather: WeatherData, babyAgeInMonths: Int) -> WeatherAlert? {
        var alertConditions: [AlertCondition] = []
        
        // 1. 温度变化检查
        if currentWeather.temperature > alertThresholds.maxTemperature {
            alertConditions.append(AlertCondition(
                type: .highTemperature,
                level: .warning,
                message: "温度过高 (\(Int(currentWeather.temperature))°C)，不建议带宝宝外出",
                recommendation: "建议在室内活动，保持室内凉爽，避免中暑"
            ))
        } else if currentWeather.temperature < alertThresholds.minTemperature {
            alertConditions.append(AlertCondition(
                type: .lowTemperature,
                level: .warning,
                message: "温度过低 (\(Int(currentWeather.temperature))°C)，外出需注意保暖",
                recommendation: "外出时请给宝宝穿戴足够的保暖衣物"
            ))
        }
        
        // 2. 紫外线检查
        if currentWeather.uvIndex > alertThresholds.maxUVIndex {
            let level: AlertLevel = currentWeather.uvIndex > 10 ? .danger : .warning
            alertConditions.append(AlertCondition(
                type: .highUV,
                level: level,
                message: "紫外线强烈 (\(Int(currentWeather.uvIndex)))，注意防晒",
                recommendation: "避免在正午外出，如必须外出请使用婴儿遮阳伞和防晒措施"
            ))
        }
        
        // 3. 空气质量检查
        if currentWeather.aqi > alertThresholds.maxAQI {
            alertConditions.append(AlertCondition(
                type: .poorAirQuality,
                level: .warning,
                message: "空气质量不佳 (AQI: \(currentWeather.aqi))",
                recommendation: "建议减少户外活动时间，外出可佩戴婴儿口罩"
            ))
        }
        
        // 4. 风速检查
        if currentWeather.windSpeed > alertThresholds.maxWindSpeed {
            alertConditions.append(AlertCondition(
                type: .highWind,
                level: .warning,
                message: "风速较大 (\(Int(currentWeather.windSpeed)) km/h)",
                recommendation: "外出时注意避风，给宝宝穿戴防风外套"
            ))
        }
        
        // 5. 湿度检查
        if currentWeather.humidity > alertThresholds.maxHumidity {
            alertConditions.append(AlertCondition(
                type: .highHumidity,
                level: .caution,
                message: "湿度较高 (\(Int(currentWeather.humidity))%)",
                recommendation: "注意宝宝皮肤护理，避免湿疹"
            ))
        } else if currentWeather.humidity < alertThresholds.minHumidity {
            alertConditions.append(AlertCondition(
                type: .lowHumidity,
                level: .caution,
                message: "空气干燥 (\(Int(currentWeather.humidity))%)",
                recommendation: "可使用加湿器，注意宝宝皮肤保湿"
            ))
        }
        
        // 6. 小宝宝特殊提醒 (0-6个月)
        if babyAgeInMonths <= 6 && !alertConditions.isEmpty {
            alertConditions.append(AlertCondition(
                type: .babyAgeReminder,
                level: .caution,
                message: "宝宝月龄较小 (\(babyAgeInMonths)个月)，对天气更敏感",
                recommendation: "建议谨慎外出，优先选择室内活动"
            ))
        }
        
        // 检查是否与上次有变化（避免重复提醒）
        let shouldAlert = shouldSendAlert(newConditions: alertConditions)
        
        if !alertConditions.isEmpty && shouldAlert {
            let alert = WeatherAlert(
                id: UUID(),
                timestamp: Date(),
                conditions: alertConditions,
                weather: currentWeather,
                highestLevel: alertConditions.map { $0.level }.max() ?? .caution
            )
            
            lastAlert = alert
            previousWeather = currentWeather
            
            // 发送本地通知
            sendNotification(alert: alert)
            
            return alert
        }
        
        return nil
    }
    
    /// 判断是否需要发送新提醒（避免重复）
    private func shouldSendAlert(newConditions: [AlertCondition]) -> Bool {
        guard let lastAlert = lastAlert else { return true }
        
        // 距离上次提醒超过30分钟才重新提醒
        let timeSinceLastAlert = Date().timeIntervalSince(lastAlert.timestamp)
        if timeSinceLastAlert > 30 * 60 {
            return true
        }
        
        // 如果有新的预警类型，也需要提醒
        let lastTypes = Set(lastAlert.conditions.map { $0.type })
        let newTypes = Set(newConditions.map { $0.type })
        
        return !newTypes.isSubset(of: lastTypes)
    }
    
    // MARK: - 通知发送
    
    private func sendNotification(alert: WeatherAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.notificationTitle
        content.body = alert.notificationBody
        content.sound = .default
        
        // 立即发送通知
        let request = UNNotificationRequest(
            identifier: "weather-alert-\(alert.id.uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("天气提醒通知发送失败: \(error)")
            }
        }
    }
    
    // MARK: - 阈值配置
    
    public func updateThresholds(_ thresholds: AlertThresholds) {
        self.alertThresholds = thresholds
    }
    
    public func getCurrentThresholds() -> AlertThresholds {
        return alertThresholds
    }
}

// MARK: - 数据模型

/// 天气提醒
public struct WeatherAlert: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let conditions: [AlertCondition]
    public let weather: WeatherData
    public let highestLevel: AlertLevel
    
    public var notificationTitle: String {
        switch highestLevel {
        case .danger:
            return "⚠️ 天气预警 - 不建议外出"
        case .warning:
            return "⚡ 天气变化提醒"
        case .caution:
            return "💡 外出注意事项"
        }
    }
    
    public var notificationBody: String {
        let conditionTexts = conditions.map { $0.message }
        return conditionTexts.joined(separator: "；")
    }
}

/// 预警条件
public struct AlertCondition: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let type: AlertType
    public let level: AlertLevel
    public let message: String
    public let recommendation: String
}

/// 预警类型
public enum AlertType: String, Codable {
    case highTemperature = "high_temperature"
    case lowTemperature = "low_temperature"
    case highUV = "high_uv"
    case poorAirQuality = "poor_air_quality"
    case highWind = "high_wind"
    case highHumidity = "high_humidity"
    case lowHumidity = "low_humidity"
    case babyAgeReminder = "baby_age_reminder"
}

/// 预警级别
public enum AlertLevel: Int, Codable, Comparable {
    case caution = 1   // 注意
    case warning = 2   // 警告
    case danger = 3    // 危险
    
    public var color: String {
        switch self {
        case .caution: return "yellow"
        case .warning: return "orange"
        case .danger: return "red"
        }
    }
    
    public static func < (lhs: AlertLevel, rhs: AlertLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}
