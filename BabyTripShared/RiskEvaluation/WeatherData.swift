//
//  WeatherData.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation

public struct WeatherData: Codable, Equatable {
    /// 当前温度（摄氏度）
    public let temperature: Double
    
    /// 体感温度（摄氏度）
    public let feelsLike: Double
    
    /// 紫外线指数 (0-11+)
    public let uvIndex: Double
    
    /// 空气质量指数 (AQI)
    public let aqi: Int
    
    /// 风速（公里/小时）
    public let windSpeed: Double
    
    /// 天气状况描述
    public let condition: String
    
    /// 湿度百分比
    public let humidity: Double
    
    public init(
        temperature: Double,
        feelsLike: Double,
        uvIndex: Double,
        aqi: Int,
        windSpeed: Double,
        condition: String,
        humidity: Double
    ) {
        self.temperature = temperature
        self.feelsLike = feelsLike
        self.uvIndex = uvIndex
        self.aqi = aqi
        self.windSpeed = windSpeed
        self.condition = condition
        self.humidity = humidity
    }
    
    /// 默认空数据
    public static let empty = WeatherData(
        temperature: 0,
        feelsLike: 0,
        uvIndex: 0,
        aqi: 0,
        windSpeed: 0,
        condition: "未知",
        humidity: 0
    )
}
