//
//  TripAdvisor.swift
//  BabyTripShared
//
//  统一出行建议服务：整合所有评估模块，做最终裁决
//

import Foundation

// MARK: - 统一出行建议结果
public struct TripAdvice: Equatable {
    /// 最终裁决：是否适合外出
    public let isSuitableForTrip: Bool
    
    /// 风险等级
    public let riskLevel: RiskLevel
    
    /// 综合评分 (0-100，越高越好)
    public let overallScore: Int
    
    /// 一句话总结
    public let summary: String
    
    /// 详细原因列表
    public let blockingReasons: [String]
    public let warningReasons: [String]
    public let positiveReasons: [String]
    
    /// 建议行动
    public let actionRecommendations: [String]
    
    /// 穿衣建议（如果有）
    public let clothingAdvice: ClothingAdvice?
    
    /// 最佳外出时间（仅当适合外出时有效）
    public let recommendedTimeSlots: [RecommendedTimeSlot]
    
    /// 昨日对比
    public let yesterdayComparison: WeatherComparison?
    
    /// 原始天气数据
    public let weatherData: WeatherData
    
    /// 宝宝信息
    public let babyProfile: BabyProfile
    
    public init(
        isSuitableForTrip: Bool,
        riskLevel: RiskLevel,
        overallScore: Int,
        summary: String,
        blockingReasons: [String],
        warningReasons: [String],
        positiveReasons: [String],
        actionRecommendations: [String],
        clothingAdvice: ClothingAdvice?,
        recommendedTimeSlots: [RecommendedTimeSlot],
        yesterdayComparison: WeatherComparison?,
        weatherData: WeatherData,
        babyProfile: BabyProfile
    ) {
        self.isSuitableForTrip = isSuitableForTrip
        self.riskLevel = riskLevel
        self.overallScore = overallScore
        self.summary = summary
        self.blockingReasons = blockingReasons
        self.warningReasons = warningReasons
        self.positiveReasons = positiveReasons
        self.actionRecommendations = actionRecommendations
        self.clothingAdvice = clothingAdvice
        self.recommendedTimeSlots = recommendedTimeSlots
        self.yesterdayComparison = yesterdayComparison
        self.weatherData = weatherData
        self.babyProfile = babyProfile
    }
}

// MARK: - 统一出行建议服务
public final class TripAdvisor {
    
    private let riskEvaluator = RiskEvaluator()
    private let recommendationEngine = TripRecommendationEngine()
    
    public init() {}
    
    /// 获取统一出行建议（唯一入口）
    public func getAdvice(
        baby: BabyProfile,
        weather: WeatherData,
        hourlyForecast: [HourlyWeather] = [],
        currentAQI: Int = 0,
        currentUV: Double = 0,
        yesterdayComparison: WeatherComparison? = nil
    ) -> TripAdvice {
        
        // 1. 评估当前天气风险
        let riskResult = riskEvaluator.evaluate(baby: baby, weather: weather)
        
        // 2. 硬过滤检查（一票否决制）
        let hardFilterResult = checkHardFilters(weather: weather)
        
        // 3. 评估最佳时间段
        let timeSlots = generateTimeSlots(
            hourly: hourlyForecast,
            currentAQI: currentAQI,
            currentUV: currentUV,
            hardFilter: hardFilterResult
        )
        
        // 4. 生成穿衣建议（仅在可能外出时）
        let clothing = generateClothingAdvice(
            weather: weather,
            hardFilter: hardFilterResult
        )
        
        // 5. 最终裁决
        let finalDecision = makeFinalDecision(
            riskResult: riskResult,
            hardFilter: hardFilterResult,
            timeSlots: timeSlots
        )
        
        // 6. 生成统一总结
        let summary = generateUnifiedSummary(
            decision: finalDecision,
            baby: baby,
            weather: weather,
            riskResult: riskResult
        )
        
        // 7. 分类整理原因
        let (blocking, warnings, positives) = categorizeReasons(
            riskResult: riskResult,
            hardFilter: hardFilterResult,
            weather: weather
        )
        
        // 8. 生成行动建议
        let actions = generateActionRecommendations(
            decision: finalDecision,
            riskResult: riskResult,
            timeSlots: timeSlots
        )
        
        return TripAdvice(
            isSuitableForTrip: finalDecision.isSuitable,
            riskLevel: finalDecision.riskLevel,
            overallScore: finalDecision.score,
            summary: summary,
            blockingReasons: blocking,
            warningReasons: warnings,
            positiveReasons: positives,
            actionRecommendations: actions,
            clothingAdvice: clothing,
            recommendedTimeSlots: finalDecision.isSuitable ? timeSlots : [], // 不适合时清空推荐
            yesterdayComparison: yesterdayComparison,
            weatherData: weather,
            babyProfile: baby
        )
    }
    
    // MARK: - 硬过滤检查（一票否决）
    private func checkHardFilters(weather: WeatherData) -> HardFilterResult {
        var blockingReasons: [String] = []
        var isBlocked = false
        
        // 恶劣天气关键词
        let badWeatherKeywords = ["雨", "雪", "雷", "沙", "尘", "雹", "雾", "霾"]
        for keyword in badWeatherKeywords {
            if weather.condition.contains(keyword) {
                blockingReasons.append("\(keyword)天不适合外出")
                isBlocked = true
                break
            }
        }
        
        // 风速 >= 36 km/h (10 m/s)
        if weather.windSpeed >= 36 {
            blockingReasons.append("风速过大 (\(Int(weather.windSpeed))km/h)")
            isBlocked = true
        }
        
        // AQI >= 150
        if weather.aqi >= 150 {
            blockingReasons.append("空气质量差 (AQI \(weather.aqi))")
            isBlocked = true
        }
        
        // 温度 < 0°C
        if weather.temperature < 0 {
            blockingReasons.append("温度过低 (\(Int(weather.temperature))°C)")
            isBlocked = true
        }
        
        // 体感 > 38°C
        if weather.feelsLike > 38 {
            blockingReasons.append("体感过热 (\(Int(weather.feelsLike))°C)")
            isBlocked = true
        }
        
        return HardFilterResult(
            isBlocked: isBlocked,
            blockingReasons: blockingReasons
        )
    }
    
    // MARK: - 生成时间段推荐
    private func generateTimeSlots(
        hourly: [HourlyWeather],
        currentAQI: Int,
        currentUV: Double,
        hardFilter: HardFilterResult
    ) -> [RecommendedTimeSlot] {
        // 如果被硬过滤阻止，返回空数组
        guard !hardFilter.isBlocked else {
            return []
        }
        
        guard !hourly.isEmpty else {
            return []
        }
        
        let scored = recommendationEngine.scoreHourlyWeather(
            hourly: hourly,
            currentAQI: currentAQI,
            currentUV: currentUV
        )
        
        return recommendationEngine.findBestTimeSlots(scored: scored)
    }
    
    // MARK: - 生成穿衣建议
    private func generateClothingAdvice(
        weather: WeatherData,
        hardFilter: HardFilterResult
    ) -> ClothingAdvice? {
        // 即使不适合外出，也提供穿衣建议（方便用户室内参考）
        // 但会在建议中标注
        return recommendationEngine.getClothingAdvice(
            feelsLike: weather.feelsLike,
            windSpeed: weather.windSpeed,
            condition: weather.condition
        )
    }
    
    // MARK: - 最终裁决
    private func makeFinalDecision(
        riskResult: EvaluationResult,
        hardFilter: HardFilterResult,
        timeSlots: [RecommendedTimeSlot]
    ) -> FinalDecision {
        // 优先级1：硬过滤一票否决
        if hardFilter.isBlocked {
            return FinalDecision(
                isSuitable: false,
                riskLevel: .unsafe,
                score: 0,
                reason: "硬过滤阻止: \(hardFilter.blockingReasons.joined(separator: ", "))"
            )
        }
        
        // 优先级2：风险等级评估
        let isSuitable = riskResult.riskLevel == .safe || 
                        (riskResult.riskLevel == .caution && !timeSlots.isEmpty)
        
        // 计算综合评分 (0-100)
        let score = calculateOverallScore(
            riskResult: riskResult,
            hasTimeSlots: !timeSlots.isEmpty
        )
        
        return FinalDecision(
            isSuitable: isSuitable,
            riskLevel: riskResult.riskLevel,
            score: score,
            reason: riskResult.humanSummary
        )
    }
    
    // MARK: - 计算综合评分
    private func calculateOverallScore(
        riskResult: EvaluationResult,
        hasTimeSlots: Bool
    ) -> Int {
        var score = 100 - riskResult.overallScore
        
        // 风险等级调整
        switch riskResult.riskLevel {
        case .safe:
            score = max(score, 70)
        case .caution:
            score = min(score, 60)
        case .unsafe:
            score = min(score, 30)
        }
        
        // 有推荐时段加分
        if hasTimeSlots {
            score += 10
        }
        
        return max(0, min(100, score))
    }
    
    // MARK: - 生成统一总结
    private func generateUnifiedSummary(
        decision: FinalDecision,
        baby: BabyProfile,
        weather: WeatherData,
        riskResult: EvaluationResult
    ) -> String {
        let ageDesc = getAgeDescription(ageInMonths: baby.ageInMonths)
        
        if !decision.isSuitable {
            return "今天不适合带\(ageDesc)宝宝外出，建议改为室内活动。"
        }
        
        switch decision.riskLevel {
        case .safe:
            return "今天天气条件不错，适合带\(ageDesc)宝宝外出活动。"
        case .caution:
            return riskResult.humanSummary
        case .unsafe:
            return "今天不适合带\(ageDesc)宝宝外出，建议改为室内活动。"
        }
    }
    
    // MARK: - 分类整理原因
    private func categorizeReasons(
        riskResult: EvaluationResult,
        hardFilter: HardFilterResult,
        weather: WeatherData
    ) -> (blocking: [String], warnings: [String], positives: [String]) {
        var blocking: [String] = []
        var warnings: [String] = []
        var positives: [String] = []
        
        // 硬过滤原因 = 阻断原因
        blocking.append(contentsOf: hardFilter.blockingReasons)
        
        // 风险贡献分类
        for contribution in riskResult.factorContributions {
            if contribution.points >= 20 {
                if let reason = contribution.reasons.first {
                    if !blocking.contains(reason) {
                        blocking.append(reason)
                    }
                }
            } else if contribution.points > 0 {
                if let reason = contribution.reasons.first {
                    warnings.append(reason)
                }
            }
        }
        
        // 正面因素
        if weather.feelsLike >= 18 && weather.feelsLike <= 26 {
            positives.append("温度舒适 (\(Int(weather.feelsLike))°C)")
        }
        if weather.aqi <= 50 {
            positives.append("空气优良 (AQI \(weather.aqi))")
        }
        if weather.uvIndex < 3 {
            positives.append("紫外线较低")
        }
        if weather.windSpeed < 15 {
            positives.append("风速适宜")
        }
        
        return (blocking, warnings, positives)
    }
    
    // MARK: - 生成行动建议
    private func generateActionRecommendations(
        decision: FinalDecision,
        riskResult: EvaluationResult,
        timeSlots: [RecommendedTimeSlot]
    ) -> [String] {
        var actions: [String] = []
        
        if !decision.isSuitable {
            actions.append("建议改为室内活动")
            actions.append("如需外出，请严格控制时间")
        } else if decision.riskLevel == .caution {
            actions.append("可以外出，但需注意防护")
            if let bestTime = timeSlots.first {
                actions.append("建议选择时段: \(bestTime.timeRangeString)")
            }
        } else {
            actions.append("天气适宜，可以安排户外活动")
            if let bestTime = timeSlots.first {
                actions.append("最佳时段: \(bestTime.timeRangeString)")
            }
        }
        
        // 添加风险评估的建议
        actions.append(contentsOf: riskResult.recommendations.prefix(2))
        
        return Array(actions.prefix(4))
    }
    
    // MARK: - 辅助方法
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

// MARK: - 内部数据结构

private struct HardFilterResult {
    let isBlocked: Bool
    let blockingReasons: [String]
}

private struct FinalDecision {
    let isSuitable: Bool
    let riskLevel: RiskLevel
    let score: Int
    let reason: String
}
