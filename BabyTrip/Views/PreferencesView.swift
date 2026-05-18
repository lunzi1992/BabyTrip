//
//  PreferencesView.swift
//  BabyTrip
//
//  V3: 用户偏好设置页面
//

import SwiftUI
import BabyTripShared

struct PreferencesView: View {
    @EnvironmentObject var userSettings: UserSettings
    @Environment(\.dismiss) private var dismiss
    
    @State private var preferences: UserPreferences
    @State private var showingResetConfirmation = false
    
    init() {
        _preferences = State(initialValue: UserSettings.shared.preferences)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 外出偏好
                Section(header: Text("外出偏好")) {
                    // 外出时长
                    Stepper(value: $preferences.preferredOutingDuration, in: 15...180, step: 15) {
                        HStack {
                            Text("理想外出时长")
                            Spacer()
                            Text("\(preferences.preferredOutingDuration) 分钟")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 温度范围
                    VStack(alignment: .leading, spacing: 8) {
                        Text("理想温度范围")
                            .font(.subheadline)
                        HStack {
                            Text("\(Int(preferences.minOutingTemperature))°C")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Slider(value: $preferences.minOutingTemperature, in: -10...30, step: 1)
                            Slider(value: $preferences.maxOutingTemperature, in: 15...45, step: 1)
                            Text("\(Int(preferences.maxOutingTemperature))°C")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 紫外线上限
                    Stepper(value: $preferences.maxAcceptableUV, in: 1...11, step: 1) {
                        HStack {
                            Text("最大可接受紫外线")
                            Spacer()
                            Text("\(Int(preferences.maxAcceptableUV))")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // 风速上限
                    Stepper(value: $preferences.maxAcceptableWindSpeed, in: 5...50, step: 5) {
                        HStack {
                            Text("最大可接受风速")
                            Spacer()
                            Text("\(Int(preferences.maxAcceptableWindSpeed)) km/h")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // AQI上限
                    Stepper(value: .init(
                        get: { Double(preferences.maxAcceptableAQI) },
                        set: { preferences.maxAcceptableAQI = Int($0) }
                    ), in: 50...300, step: 10) {
                        HStack {
                            Text("最大可接受 AQI")
                            Spacer()
                            Text("\(preferences.maxAcceptableAQI)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // MARK: - 提醒设置
                Section(header: Text("提醒设置")) {
                    Toggle("启用天气变化提醒", isOn: $preferences.enableWeatherAlerts)
                    
                    if preferences.enableWeatherAlerts {
                        Stepper(value: $preferences.alertInterval, in: 15...120, step: 15) {
                            HStack {
                                Text("提醒间隔")
                                Spacer()
                                Text("\(preferences.alertInterval) 分钟")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Toggle("仅在适合外出时提醒", isOn: $preferences.alertOnlyWhenSuitable)
                    }
                }
                
                // MARK: - 显示设置
                Section(header: Text("显示设置")) {
                    Toggle("优先显示体感温度", isOn: $preferences.prioritizeFeelsLike)
                    Toggle("显示详细风险分析", isOn: $preferences.showDetailedAnalysis)
                    
                    Picker("温度单位", selection: $preferences.temperatureUnit) {
                        Text("摄氏度 °C").tag(TemperatureUnit.celsius)
                        Text("华氏度 °F").tag(TemperatureUnit.fahrenheit)
                    }
                }
                
                // MARK: - 偏好外出时间段
                Section(header: Text("偏好外出时间段")) {
                    ForEach($preferences.preferredOutingTimes) { $time in
                        HStack {
                            Toggle(isOn: $time.isEnabled) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(time.label.isEmpty ? "时间段" : time.label)
                                        .font(.subheadline)
                                    Text(time.formattedTimeRange)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    Text("根据您的偏好时段，我们会推荐最适合的外出时间")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // MARK: - 重置
                Section {
                    Button("恢复默认设置") {
                        showingResetConfirmation = true
                    }
                    .foregroundColor(.red)
                    .centered()
                }
            }
            .navigationTitle("偏好设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        savePreferences()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("恢复默认设置", isPresented: $showingResetConfirmation) {
                Button("取消", role: .cancel) { }
                Button("恢复", role: .destructive) {
                    preferences = UserPreferences()
                }
            } message: {
                Text("这将重置所有偏好设置为默认值，确定要继续吗？")
            }
        }
    }
    
    private func savePreferences() {
        userSettings.savePreferences(preferences)
        dismiss()
    }
}

// MARK: - 辅助扩展

extension View {
    func centered() -> some View {
        HStack {
            Spacer()
            self
            Spacer()
        }
    }
}

// MARK: - 预览

struct PreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        PreferencesView()
            .environmentObject(UserSettings.shared)
    }
}
