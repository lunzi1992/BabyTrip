//
//  RiskEvaluator.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//  V2: 全新评分系统（体感温度+湿度+年龄权重）
//

import Foundation

public final class RiskEvaluator {
    public init() {}
    
    /// 根据宝宝信息和天气数据评估出行风险（V2评分系统）
    public func evaluate(
        baby: BabyProfile,
        weather: WeatherData
    ) -> EvaluationResult {
        // 计算各因素的风险贡献
        var contributions: [RiskFactorContribution] = []
        var recommendations: [String] = []
        
        // 1. 温度评分
        let tempContribution = evaluateTemperature(temperature: weather.temperature)
        contributions.append(tempContribution)
        if tempContribution.points > 0 {
            recommendations.append(contentsOf: tempContribution.recommendations)
        }
        
        // 2. 体感温度评分
        let feelsLikeContribution = evaluateFeelsLike(feelsLike: weather.feelsLike)
        contributions.append(feelsLikeContribution)
        if feelsLikeContribution.points > 0 {
            recommendations.append(contentsOf: feelsLikeContribution.recommendations)
        }
        
        // 3. 紫外线评分
        let uvContribution = evaluateUV(uvIndex: weather.uvIndex)
        contributions.append(uvContribution)
        if uvContribution.points > 0 {
            recommendations.append(contentsOf: uvContribution.recommendations)
        }
        
        // 4. 空气质量评分
        let aqiContribution = evaluateAQI(aqi: weather.aqi)
        contributions.append(aqiContribution)
        if aqiContribution.points > 0 {
            recommendations.append(contentsOf: aqiContribution.recommendations)
        }
        
        // 5. 风速评分
        let windContribution = evaluateWind(windSpeed: weather.windSpeed)
        contributions.append(windContribution)
        if windContribution.points > 0 {
            recommendations.append(contentsOf: windContribution.recommendations)
        }
        
        // 6. 湿度评分
        let humidityContribution = evaluateHumidity(humidity: weather.humidity)
        contributions.append(humidityContribution)
        if humidityContribution.points > 0 {
            recommendations.append(contentsOf: humidityContribution.recommendations)
        }
        
        // 7. 天气状况评分（V2新增：恶劣天气检测）
        let weatherConditionContribution = evaluateWeatherCondition(condition: weather.condition)
        contributions.append(weatherConditionContribution)
        if weatherConditionContribution.points > 0 {
            recommendations.append(contentsOf: weatherConditionContribution.recommendations)
        }
        
        // 计算基础风险分（各项累加）
        let baseScore = contributions.reduce(0) { $0 + $1.points }
        
        // 应用年龄权重
        let ageMultiplier = getAgeMultiplier(ageInMonths: baby.ageInMonths)
        let finalScore = Int(Double(baseScore) * ageMultiplier)
        
        // 确定风险等级（V2阈值：0-30安全，30-60谨慎，>60不建议）
        let riskLevel = determineRiskLevelV2(from: finalScore)
        
        // 生成人话总结
        let humanSummary = generateHumanSummary(
            riskLevel: riskLevel,
            babyAge: baby.ageInMonths,
            topContributions: contributions.filter { $0.points > 0 }.sorted { $0.points > $1.points }.prefix(2).map { $0 }
        )
        
        // 去重并限制建议数量
        let uniqueRecommendations = Array(recommendations.prefix(3))
        
        return EvaluationResult(
            overallScore: finalScore,
            riskLevel: riskLevel,
            factorContributions: contributions,
            recommendations: uniqueRecommendations,
            humanSummary: humanSummary,
            bestTimeRange: nil
        )
    }
    
    // MARK: - 各因素评估（V2评分规则）
    
    /// 温度评估（>32: +25, <5: +30）
    private func evaluateTemperature(temperature: Double) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if temperature > 32 {
            points += 25
            reasons.append("温度过高（\(Int(temperature))°C）")
            recommendations.append("避免正午时段外出，选择早晚较凉爽时间")
        } else if temperature < 5 {
            points += 30
            reasons.append("温度过低（\(Int(temperature))°C）")
            recommendations.append("注意保暖，外出时间控制在15分钟以内")
        }
        
        return RiskFactorContribution(
            factor: .temperature,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 体感温度评估（>35: +20）
    private func evaluateFeelsLike(feelsLike: Double) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if feelsLike > 35 {
            points += 20
            reasons.append("体感闷热（\(Int(feelsLike))°C）")
            recommendations.append("天气闷热，宝宝容易出汗，注意及时补水")
        } else if feelsLike < 0 {
            points += 15
            reasons.append("体感寒冷（\(Int(feelsLike))°C）")
            recommendations.append("体感温度低，加强保暖措施")
        }
        
        return RiskFactorContribution(
            factor: .feelsLike,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 紫外线评估（>=7: +25, >=4: +10）
    private func evaluateUV(uvIndex: Double) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if uvIndex >= 7 {
            points += 25
            reasons.append("紫外线过强（UV \(Int(uvIndex))）")
            recommendations.append("紫外线强烈，使用遮阳车篷或遮阳伞")
            recommendations.append("避免阳光直射，尽量选择阴凉区域活动")
        } else if uvIndex >= 4 {
            points += 10
            reasons.append("紫外线偏强（UV \(Int(uvIndex))）")
            recommendations.append("注意防晒，可佩戴婴儿遮阳帽")
        }
        
        return RiskFactorContribution(
            factor: .uv,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 空气质量评估（>100: +30, >50: +15）
    private func evaluateAQI(aqi: Int) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if aqi > 100 {
            points += 30
            reasons.append("空气质量不佳（AQI \(aqi)）")
            recommendations.append("空气污染，建议改为室内活动")
            recommendations.append("如必须外出，佩戴防护口罩并缩短时间")
        } else if aqi > 50 {
            points += 15
            reasons.append("空气质量一般（AQI \(aqi)）")
            recommendations.append("空气质量一般，避免长时间户外停留")
        }
        
        return RiskFactorContribution(
            factor: .aqi,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 风速评估（>25: +10）
    private func evaluateWind(windSpeed: Double) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if windSpeed > 25 {
            points += 10
            reasons.append("风力较大（\(Int(windSpeed)) km/h）")
            recommendations.append("风力较大，注意避风，保护好宝宝头部")
        } else if windSpeed > 15 {
            recommendations.append("风速偏大，注意给宝宝挡风")
        }
        
        return RiskFactorContribution(
            factor: .wind,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 湿度评估（>90: +15, >80: +10）
    private func evaluateHumidity(humidity: Double) -> RiskFactorContribution {
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        if humidity > 90 {
            points += 15
            reasons.append("湿度过高（\(Int(humidity))%）")
            recommendations.append("湿度高，天气闷热，注意保持宝宝皮肤干爽")
        } else if humidity > 80 {
            points += 10
            reasons.append("湿度偏高（\(Int(humidity))%）")
            recommendations.append("湿度偏高，注意给宝宝穿透气衣物")
        } else if humidity < 30 {
            points += 5
            reasons.append("空气干燥（\(Int(humidity))%）")
            recommendations.append("空气干燥，注意给宝宝补水")
        }
        
        return RiskFactorContribution(
            factor: .humidity,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 天气状况评估（V2新增：恶劣天气直接高风险）
    public func evaluateWeatherCondition(condition: String) -> RiskFactorContribution {
        let badWeatherKeywords = ["雨", "雪", "雷", "沙", "尘", "雹", "雾", "霾"]
        
        var points = 0
        var reasons: [String] = []
        var recommendations: [String] = []
        
        // 检查是否包含恶劣天气关键词
        for keyword in badWeatherKeywords {
            if condition.contains(keyword) {
                points += 50  // 恶劣天气直接加50分（高风险）
                reasons.append("\(keyword)天不适合外出（\(condition)）")
                recommendations.append("\(keyword)天气，建议改为室内活动")
                break  // 找到一个就停止，避免重复计分
            }
        }
        
        return RiskFactorContribution(
            factor: .weatherCondition,
            points: points,
            reasons: reasons,
            recommendations: recommendations
        )
    }
    
    /// 计算最佳外出时间
    public func calculateBestTimeRange(
        forecast: [(date: Date, temperature: Double, feelsLike: Double, humidity: Double, windSpeed: Double)],
        babyAgeInMonths: Int
    ) -> TimeRange? {
        // 计算每个时段的风险分（简化版，主要考虑温度、体感温度、湿度）
        var scoredForecast: [(date: Date, score: Int, reasons: [String])] = []
        
        for item in forecast {
            var score = 0
            var reasons: [String] = []
            
            // 温度评分
            if item.temperature > 32 {
                score += 20
                reasons.append("温度偏高")
            } else if item.temperature < 5 {
                score += 25
                reasons.append("温度偏低")
            }
            
            // 体感温度
            if item.feelsLike > 35 {
                score += 15
                reasons.append("体感闷热")
            } else if item.feelsLike < 0 {
                score += 10
                reasons.append("体感寒冷")
            }
            
            // 湿度
            if item.humidity > 90 {
                score += 10
                reasons.append("湿度过高")
            } else if item.humidity > 80 {
                score += 5
                reasons.append("湿度偏高")
            }
            
            // 风速
            if item.windSpeed > 25 {
                score += 5
                reasons.append("风力较大")
            }
            
            scoredForecast.append((date: item.date, score: score, reasons: reasons))
        }
        
        // 找出连续2-3小时的最低风险时段
        guard scoredForecast.count >= 2 else { return nil }
        
        var bestStartIndex = 0
        var bestScore = Int.max
        
        // 滑动窗口找最佳连续时段（2-3小时）
        for i in 0...(scoredForecast.count - 2) {
            let windowEnd = min(i + 3, scoredForecast.count)
            var windowScore = 0
            
            for j in i..<windowEnd {
                windowScore += scoredForecast[j].score
            }
            
            // 优先选择评分低的时段，其次选择更晚的时段（方便用户准备）
            if windowScore < bestScore || (windowScore == bestScore && i > bestStartIndex) {
                bestScore = windowScore
                bestStartIndex = i
            }
        }
        
        // 构建时间范围（选择连续2小时）
        let startTime = scoredForecast[bestStartIndex].date
        let endIndex = min(bestStartIndex + 2, scoredForecast.count - 1)
        let endTime = scoredForecast[endIndex].date
        
        // 生成原因说明
        let reasons = scoredForecast[bestStartIndex...endIndex].flatMap { $0.reasons }
        let uniqueReasons = Array(Set(reasons)).prefix(2)
        
        let reasonText: String
        if uniqueReasons.isEmpty {
            reasonText = "该时段天气条件相对较好"
        } else if uniqueReasons.count == 1 {
            reasonText = "相比其他时段\(uniqueReasons[0])较轻"
        } else {
            reasonText = "相比其他时段\(uniqueReasons.joined(separator: "、"))较轻"
        }
        
        return TimeRange(start: startTime, end: endTime, reason: reasonText)
    }
    
    // MARK: - 辅助方法
    
    /// 获取年龄权重（V2规则）
    private func getAgeMultiplier(ageInMonths: Int) -> Double {
        if ageInMonths <= 3 {
            return 1.5  // 新生儿：高敏感
        } else if ageInMonths <= 6 {
            return 1.2  // 小婴儿：中高敏感
        } else {
            return 1.0  // 婴儿：中等敏感
        }
    }
    
    /// V2风险等级判定（0-30安全，30-60谨慎，>60不建议）
    private func determineRiskLevelV2(from score: Int) -> RiskLevel {
        if score <= 30 {
            return .safe
        } else if score <= 60 {
            return .caution
        } else {
            return .unsafe
        }
    }
    
    /// 生成人话总结
    private func generateHumanSummary(
        riskLevel: RiskLevel,
        babyAge: Int,
        topContributions: [RiskFactorContribution]
    ) -> String {
        let ageDesc = getAgeDescription(ageInMonths: babyAge)
        
        switch riskLevel {
        case .safe:
            return "今天天气条件不错，适合带\(ageDesc)宝宝外出活动。"
        case .caution:
            let factorDesc = topContributions.first?.reasons.first ?? "部分环境因素"
            return "\(factorDesc)，带\(ageDesc)宝宝外出需谨慎，注意防护。"
        case .unsafe:
            let factorDesc = topContributions.prefix(2).map { $0.reasons.first ?? "" }.filter { !$0.isEmpty }.joined(separator: "，")
            return "\(factorDesc)，不太适合带\(ageDesc)宝宝外出，建议改为室内活动。"
        }
    }
    
    /// 获取年龄段描述
    private func getAgeDescription(ageInMonths: Int) -> String {
        if ageInMonths <= 3 {
            return "新生儿阶段"
        } else if ageInMonths <= 6 {
            return "小婴儿阶段"
        } else {
            return "婴儿阶段"
        }
    }
}

// MARK: - V2 数据模型

/// 风险因素贡献（用于原因解释）
public struct RiskFactorContribution: Identifiable, Codable, Equatable {
    public let id = UUID()
    public let factor: RiskFactor
    public let points: Int
    public let reasons: [String]
    public let recommendations: [String]
    
    public init(factor: RiskFactor, points: Int, reasons: [String], recommendations: [String]) {
        self.factor = factor
        self.points = points
        self.reasons = reasons
        self.recommendations = recommendations
    }
}

/// 时间范围（用于最佳外出时间）
public struct TimeRange: Codable, Equatable {
    public let start: Date
    public let end: Date
    public let reason: String
    
    public init(start: Date, end: Date, reason: String) {
        self.start = start
        self.end = end
        self.reason = reason
    }
}
