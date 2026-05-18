//
//  WeatherConfig.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//
//  天气 API 配置管理类，从 WeatherConfig.plist 读取配置
//

import Foundation

public struct WeatherConfig {
    
    // MARK: - 配置键名
    private enum Keys {
        static let apiBaseURL = "APIBaseURL"
        static let geoAPIBaseURL = "GeoAPIBaseURL"
        static let airQualityAPIBaseURL = "AirQualityAPIBaseURL"
        static let requestTimeout = "RequestTimeout"
        static let resourceTimeout = "ResourceTimeout"
    }
    
    // MARK: - 默认值（仅超时等行为参数保留默认值，URL 配置以 plist 为准）
    private enum Defaults {
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 300
    }
    
    // MARK: - 共享实例
    public static let shared = WeatherConfig()
    
    private let config: [String: Any]
    
    private init() {
        // 尝试从 Bundle 加载 WeatherConfig.plist
        guard let url = Bundle.main.url(forResource: "WeatherConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            print("[WeatherConfig] 无法加载 WeatherConfig.plist，使用默认配置")
            self.config = [:]
            return
        }
        self.config = plist
        print("[WeatherConfig] 成功加载配置文件")
    }
    
    // MARK: - API 端点配置
    
    /// 天气 API 基础 URL
    public var apiBaseURL: String {
        guard let url = config[Keys.apiBaseURL] as? String, !url.isEmpty else {
            fatalError("[WeatherConfig] plist 中缺少 APIBaseURL 配置，请检查 WeatherConfig.plist")
        }
        return url
    }
    
    /// 地理 API 基础 URL
    public var geoAPIBaseURL: String {
        guard let url = config[Keys.geoAPIBaseURL] as? String, !url.isEmpty else {
            fatalError("[WeatherConfig] plist 中缺少 GeoAPIBaseURL 配置，请检查 WeatherConfig.plist")
        }
        return url
    }
    
    /// 空气质量 API 基础 URL
    public var airQualityAPIBaseURL: String {
        guard let url = config[Keys.airQualityAPIBaseURL] as? String, !url.isEmpty else {
            fatalError("[WeatherConfig] plist 中缺少 AirQualityAPIBaseURL 配置，请检查 WeatherConfig.plist")
        }
        return url
    }
    
    // MARK: - 网络超时配置
    
    /// 请求超时时间（秒）
    public var requestTimeout: TimeInterval {
        config[Keys.requestTimeout] as? TimeInterval ?? Defaults.requestTimeout
    }
    
    /// 资源超时时间（秒）
    public var resourceTimeout: TimeInterval {
        config[Keys.resourceTimeout] as? TimeInterval ?? Defaults.resourceTimeout
    }
}
