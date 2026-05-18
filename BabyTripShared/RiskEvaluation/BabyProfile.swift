//
//  BabyProfile.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation

public struct BabyProfile: Codable, Equatable {
    public var birthDate: Date
    public var name: String
    
    public init(birthDate: Date, name: String = "") {
        self.birthDate = birthDate
        self.name = name
    }
    
    /// 宝宝年龄（月份）
    public var ageInMonths: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return components.month ?? 0
    }
    
    /// 宝宝年龄分类
    public var ageCategory: AgeCategory {
        let months = ageInMonths
        if months < 3 {
            return .newborn
        } else if months < 6 {
            return .threeToSixMonths
        } else if months < 12 {
            return .sixToTwelveMonths
        } else {
            return .oneYearPlus
        }
    }
    
    public enum AgeCategory: Int, Codable, CaseIterable {
        case newborn          // 0-3个月
        case threeToSixMonths // 3-6个月
        case sixToTwelveMonths // 6-12个月
        case oneYearPlus      // 1岁以上
        
        public var description: String {
            switch self {
            case .newborn:
                return "新生儿 (0-3个月)"
            case .threeToSixMonths:
                return "3-6个月"
            case .sixToTwelveMonths:
                return "6-12个月"
            case .oneYearPlus:
                return "1岁以上"
            }
        }
        
        /// 年龄系数，年龄越小，安全阈值越严格
        public var sensitivityFactor: Double {
            switch self {
            case .newborn:
                return 1.5 // 更加敏感
            case .threeToSixMonths:
                return 1.3
            case .sixToTwelveMonths:
                return 1.1
            case .oneYearPlus:
                return 1.0 // 标准敏感度
            }
        }
    }
}

extension BabyProfile: Identifiable {
    public var id: UUID {
        UUID()
    }
}
