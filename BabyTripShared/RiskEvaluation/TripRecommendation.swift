//
//  TripRecommendation.swift
//  BabyTripShared
//
//  V4: 最佳外出时间推荐、穿衣指南、昨日对比
//

import Foundation

// MARK: - 每小时天气数据（带评分）
public struct HourlyWeatherScore: Identifiable {
    public let id = UUID()
    public let date: Date
    public let temp: Double
    public let feelsLike: Double
    public let humidity: Double
    public let windSpeed: Double
    public let condition: String
    public let aqi: Int
    public let uvIndex: Double
    
    // 评分结果
    public let score: Int
    public let isAvailable: Bool
    public let unavailableReason: String?
    
    public var hourString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - 推荐时间段
public struct RecommendedTimeSlot: Identifiable, Equatable {
    public let id = UUID()
    public let startTime: Date
    public let endTime: Date
    public let score: Int
    public let reasons: [String]
    public let isBest: Bool
    
    public var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return "\(formatter.string(from: startTime)) - \(formatter.string(from: endTime))"
    }
}

// MARK: - 穿衣建议
public struct ClothingAdvice: Equatable {
    public let baseLayers: [String]
    public let accessories: [String]
    public let notes: [String]
    public let feelsLike: Double
    
    public var fullAdvice: String {
        var parts: [String] = []
        parts.append(contentsOf: baseLayers)
        if !accessories.isEmpty {
            parts.append("+")
            parts.append(contentsOf: accessories)
        }
        return parts.joined(separator: " + ")
    }
}

// MARK: - 昨日对比结果
public struct WeatherComparison: Equatable {
    public let todayScore: Int
    public let yesterdayScore: Int
    public let isTodayBetter: Bool
    public let improvements: [String]
    public let degradations: [String]
    
    public var summaryText: String {
        if isTodayBetter {
            return "今天更适合外出"
        } else if todayScore == yesterdayScore {
            return "今天和昨天差不多"
        } else {
            return "今天不如昨天适合"
        }
    }
}

// MARK: - 出行推荐引擎
public class TripRecommendationEngine {
    
    // MARK: - 硬过滤条件
    private func checkHardFilter(hour: HourlyWeather) -> (available: Bool, reason: String?) {
        // 恶劣天气
        let badWeatherKeywords = ["雨", "雪", "雷", "沙", "尘", "雹", "雾", "霾"]
        for keyword in badWeatherKeywords {
            if hour.text.contains(keyword) {
                return (false, "\(keyword)天不适合外出")
            }
        }
        
        // 风速 >= 10 m/s (36 km/h)
        if hour.windSpeedValue >= 36 {
            return (false, "风速过大 (\(Int(hour.windSpeedValue))km/h)")
        }
        
        // AQI >= 150
        if hour.aqi >= 150 {
            return (false, "空气质量差 (AQI \(hour.aqi))")
        }
        
        // 温度 < 0°C
        if hour.temperature < 0 {
            return (false, "温度过低 (\(Int(hour.temperature))°C)")
        }
        
        // 体感 > 38°C
        if hour.feelsLike > 38 {
            return (false, "体感过热 (\(Int(hour.feelsLike))°C)")
        }
        
        return (true, nil)
    }
    
    // MARK: - 硬过滤条件（带外部 AQI 参数）
    public func checkHardFilter(hour: HourlyWeather, aqi: Int) -> (available: Bool, reason: String?) {
        // 使用传入的 AQI 替代 hour.aqi
        let tempAqi = hour.aqi
        // 临时覆盖 AQI 值进行判断
        struct TempHour: HourlyWeather {
            let base: HourlyWeather
            let overrideAqi: Int
            var date: Date? { base.date }
            var temperature: Double { base.temperature }
            var feelsLike: Double { base.feelsLike }
            var humidityValue: Double { base.humidityValue }
            var windSpeedValue: Double { base.windSpeedValue }
            var text: String { base.text }
            var aqi: Int { overrideAqi }
            var uvIndex: Double { base.uvIndex }
        }
        let tempHour = TempHour(base: hour, overrideAqi: aqi)
        return checkHardFilter(hour: tempHour)
    }
    
    // MARK: - 软评分（带外部 AQI/UV 参数）
    public func calculateScore(hour: HourlyWeather, aqi: Int, uv: Double) -> Int {
        struct TempHour: HourlyWeather {
            let base: HourlyWeather
            let overrideAqi: Int
            let overrideUv: Double
            var date: Date? { base.date }
            var temperature: Double { base.temperature }
            var feelsLike: Double { base.feelsLike }
            var humidityValue: Double { base.humidityValue }
            var windSpeedValue: Double { base.windSpeedValue }
            var text: String { base.text }
            var aqi: Int { overrideAqi }
            var uvIndex: Double { overrideUv }
        }
        let tempHour = TempHour(base: hour, overrideAqi: aqi, overrideUv: uv)
        return calculateScore(hour: tempHour)
    }
    
    // MARK: - 软评分（完整版，需要 UV）
    private func calculateScore(hour: HourlyWeather) -> Int {
        var score = 0
        
        // 体感温度评分
        if hour.feelsLike > 32 {
            score += 20
        } else if hour.feelsLike < 10 {
            score += 15
        } else if hour.feelsLike >= 18 && hour.feelsLike <= 26 {
            score -= 10 // 舒适温度加分
        }
        
        // 紫外线评分
        if hour.uvIndex >= 7 {
            score += 25
        } else if hour.uvIndex >= 5 {
            score += 10
        }
        
        // 空气质量评分
        if hour.aqi > 100 {
            score += 25
        } else if hour.aqi > 50 {
            score += 10
        } else if hour.aqi <= 25 {
            score -= 5 // 优秀空气质量加分
        }
        
        // 风速评分
        if hour.windSpeedValue >= 25 { // ~7 m/s
            score += 10
        } else if hour.windSpeedValue >= 15 {
            score += 5
        }
        
        // 湿度评分
        if hour.humidityValue >= 85 {
            score += 10
        } else if hour.humidityValue >= 70 {
            score += 5
        }
        
        // 天气状况评分
        let goodWeatherKeywords = ["晴", "多云", "阴"]
        let isGoodWeather = goodWeatherKeywords.contains { hour.text.contains($0) }
        if isGoodWeather {
            score -= 5 // 好天气加分
        }
        
        return max(0, score)
    }
    
    // MARK: - 生成每小时评分
    public func scoreHourlyWeather(hourly: [HourlyWeather], currentAQI: Int, currentUV: Double) -> [HourlyWeatherScore] {
        return hourly.map { hour in
            let (available, reason) = checkHardFilter(hour: hour)
            let score = available ? calculateScore(hour: hour) : 999
            
            return HourlyWeatherScore(
                date: hour.date ?? Date(),
                temp: hour.temperature,
                feelsLike: hour.feelsLike,
                humidity: hour.humidityValue,
                windSpeed: hour.windSpeedValue,
                condition: hour.text,
                aqi: currentAQI,
                uvIndex: currentUV,
                score: score,
                isAvailable: available,
                unavailableReason: reason
            )
        }
    }
    
    // MARK: - 找出最佳时间段
    public func findBestTimeSlots(scored: [HourlyWeatherScore]) -> [RecommendedTimeSlot] {
        // 过滤不可用时间点
        let available = scored.filter { $0.isAvailable }.sorted { $0.score < $1.score }
        
        guard available.count >= 2 else {
            return []
        }
        
        // 找连续时间段
        var timeSlots: [RecommendedTimeSlot] = []
        var currentStart: Date?
        var currentEnd: Date?
        var currentScore = 0
        var currentReasons: Set<String> = []
        
        for i in 0..<available.count {
            let hour = available[i]
            
            if currentStart == nil {
                currentStart = hour.date
                currentEnd = hour.date
                currentScore = hour.score
                currentReasons = Set(getReasons(for: hour))
            } else {
                // 检查是否连续（相差1小时）
                let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: currentEnd!)!
                if Calendar.current.isDate(hour.date, equalTo: nextHour, toGranularity: .hour) {
                    currentEnd = hour.date
                    currentScore = max(currentScore, hour.score)
                    currentReasons.formUnion(getReasons(for: hour))
                } else {
                    // 保存当前时间段
                    if let start = currentStart, let end = currentEnd {
                        let duration = Calendar.current.dateComponents([.hour], from: start, to: end).hour ?? 0
                        if duration >= 1 {
                            timeSlots.append(RecommendedTimeSlot(
                                startTime: start,
                                endTime: end,
                                score: currentScore,
                                reasons: Array(currentReasons).sorted(),
                                isBest: false
                            ))
                        }
                    }
                    // 开始新时间段
                    currentStart = hour.date
                    currentEnd = hour.date
                    currentScore = hour.score
                    currentReasons = Set(getReasons(for: hour))
                }
            }
        }
        
        // 添加最后一个时间段
        if let start = currentStart, let end = currentEnd {
            let duration = Calendar.current.dateComponents([.hour], from: start, to: end).hour ?? 0
            if duration >= 1 {
                timeSlots.append(RecommendedTimeSlot(
                    startTime: start,
                    endTime: end,
                    score: currentScore,
                    reasons: Array(currentReasons).sorted(),
                    isBest: false
                ))
            }
        }
        
        // 按评分排序，标记最佳
        let sorted = timeSlots.sorted { $0.score < $1.score }
        if sorted.count > 0 {
            return sorted.enumerated().map { index, slot in
                RecommendedTimeSlot(
                    startTime: slot.startTime,
                    endTime: slot.endTime,
                    score: slot.score,
                    reasons: slot.reasons,
                    isBest: index == 0
                )
            }
        }
        
        return sorted
    }
    
    // MARK: - 生成推荐理由
    private func getReasons(for hour: HourlyWeatherScore) -> [String] {
        var reasons: [String] = []
        
        if hour.uvIndex < 3 {
            reasons.append("紫外线低")
        }
        if hour.feelsLike >= 18 && hour.feelsLike <= 26 {
            reasons.append("温度舒适")
        }
        if hour.windSpeed < 15 {
            reasons.append("风速较低")
        }
        if hour.aqi <= 50 {
            reasons.append("空气优良")
        } else if hour.aqi <= 100 {
            reasons.append("空气良好")
        }
        if hour.humidity < 70 {
            reasons.append("湿度适宜")
        }
        
        return reasons.isEmpty ? ["天气适宜"] : reasons
    }
    
    // MARK: - 穿衣建议
    public func getClothingAdvice(feelsLike: Double, windSpeed: Double, condition: String) -> ClothingAdvice {
        var baseLayers: [String] = []
        var accessories: [String] = []
        var notes: [String] = []
        
        // 基础穿衣
        switch feelsLike {
        case ..<0:
            baseLayers = ["厚羽绒服", "保暖内衣", "厚长裤"]
            accessories = ["帽子", "手套", "围巾"]
        case 0..<5:
            baseLayers = ["厚外套", "保暖内衣", "厚长裤"]
            accessories = ["帽子", "手套"]
        case 5..<10:
            baseLayers = ["厚外套", "长袖", "长裤"]
            accessories = ["帽子"]
        case 10..<15:
            baseLayers = ["厚外套", "长袖", "长裤"]
        case 15..<20:
            baseLayers = ["长袖", "薄外套", "长裤"]
        case 20..<25:
            baseLayers = ["长袖", "长裤"]
        case 25..<30:
            baseLayers = ["短袖", "薄长裤"]
        default: // >= 30
            baseLayers = ["短袖", "薄衣"]
            notes.append("注意防暑")
        }
        
        // 风速修正
        if windSpeed >= 20 {
            accessories.append("防风帽子")
            notes.append("风大，注意保暖")
        }
        
        // 天气修正
        if condition.contains("雨") {
            accessories.append("雨衣/雨伞")
            notes.append("下雨，建议改室内活动")
        }
        
        return ClothingAdvice(
            baseLayers: baseLayers,
            accessories: accessories.filter { !$0.isEmpty },
            notes: notes,
            feelsLike: feelsLike
        )
    }
    
    // MARK: - 综合评分
    public func calculateOverallScore(weather: WeatherData) -> Int {
        var score = 50 // 基础分
        
        // 体感温度（最重要）
        if weather.feelsLike >= 18 && weather.feelsLike <= 26 {
            score += 30
        } else if weather.feelsLike >= 15 && weather.feelsLike <= 30 {
            score += 20
        } else if weather.feelsLike > 32 || weather.feelsLike < 10 {
            score -= 20
        }
        
        // AQI
        if weather.aqi <= 50 {
            score += 15
        } else if weather.aqi <= 100 {
            score += 5
        } else if weather.aqi > 150 {
            score -= 30
        }
        
        // 风速
        if weather.windSpeed < 15 {
            score += 10
        } else if weather.windSpeed > 30 {
            score -= 10
        }
        
        // UV
        if weather.uvIndex < 5 {
            score += 10
        } else if weather.uvIndex > 8 {
            score -= 10
        }
        
        // 天气状况 - 硬过滤：恶劣天气直接判定为不适合外出
        let badWeather = ["雨", "雪", "雷", "沙", "尘", "雹", "雾", "霾"]
        if badWeather.contains(where: { weather.condition.contains($0) }) {
            return 0  // 强制返回最低分，表示不建议外出
        }
        
        return max(0, min(100, score))
    }
}

// MARK: - 兼容原有 HourlyWeather 类型
public protocol HourlyWeather {
    var date: Date? { get }
    var temperature: Double { get }
    var feelsLike: Double { get }
    var humidityValue: Double { get }
    var windSpeedValue: Double { get }
    var text: String { get }
    var aqi: Int { get }
    var uvIndex: Double { get }
}

extension QWeatherHourlyV7: HourlyWeather {
    public var aqi: Int { return 0 }
    public var uvIndex: Double { return 0 }
    public var feelsLike: Double { return temperature } // 使用温度作为体感温度估算
}
