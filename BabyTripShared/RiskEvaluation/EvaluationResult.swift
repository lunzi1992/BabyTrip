//
//  EvaluationResult.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation

public struct EvaluationResult: Codable, Equatable {
    /// 总体风险分数（V2: 累加制，0-100+）
    public let overallScore: Int
    
    /// 整体风险等级
    public let riskLevel: RiskLevel
    
    /// V2: 各因素风险贡献（用于原因解释）
    public let factorContributions: [RiskFactorContribution]
    
    /// V2: 行动建议列表
    public let recommendations: [String]
    
    /// V2: 人话总结
    public let humanSummary: String
    
    /// V2: 最佳外出时间（可选）
    public let bestTimeRange: TimeRange?
    
    /// 兼容旧版：建议文本（取第一条建议或人话总结）
    public var recommendation: String {
        return humanSummary
    }
    
    /// 兼容旧版：各因素评分（转换后的安全分数）
    public var factorScores: [FactorScore] {
        return factorContributions.map { contribution in
            let safetyScore = max(0, 100 - contribution.points * 3)
            return FactorScore(
                factor: contribution.factor,
                score: safetyScore,
                message: contribution.reasons.first ?? ""
            )
        }
    }
    
    public init(
        overallScore: Int,
        riskLevel: RiskLevel,
        factorContributions: [RiskFactorContribution],
        recommendations: [String],
        humanSummary: String,
        bestTimeRange: TimeRange?
    ) {
        self.overallScore = overallScore
        self.riskLevel = riskLevel
        self.factorContributions = factorContributions
        self.recommendations = recommendations
        self.humanSummary = humanSummary
        self.bestTimeRange = bestTimeRange
    }
}

public struct FactorScore: Codable, Equatable, Identifiable {
    public let id = UUID()
    public let factor: RiskFactor
    public let score: Int // 0-100
    public let message: String
    
    public init(factor: RiskFactor, score: Int, message: String) {
        self.factor = factor
        self.score = score
        self.message = message
    }
}

public enum RiskLevel: Int, Codable, CaseIterable {
    case safe          // 安全，可以外出
    case caution       // 谨慎出行
    case unsafe        // 不建议外出
    
    public var description: String {
        switch self {
        case .safe:
            return "安全"
        case .caution:
            return "谨慎"
        case .unsafe:
            return "不建议"
        }
    }
    
    public var color: String {
        switch self {
        case .safe:
            return "green"
        case .caution:
            return "yellow"
        case .unsafe:
            return "red"
        }
    }
}

public enum RiskFactor: String, Codable, CaseIterable {
    case temperature
    case feelsLike
    case uv
    case aqi
    case wind
    case humidity
    case weatherCondition
    
    public var displayName: String {
        switch self {
        case .temperature:
            return "温度"
        case .feelsLike:
            return "体感温度"
        case .uv:
            return "紫外线"
        case .aqi:
            return "空气质量"
        case .wind:
            return "风速"
        case .humidity:
            return "湿度"
        case .weatherCondition:
            return "天气状况"
        }
    }
}
