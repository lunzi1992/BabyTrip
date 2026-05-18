//
//  SetupProfileView.swift
//  BabyTrip
//
//  Created by BabyTrip Project
//

import SwiftUI
import BabyTripShared

struct SetupProfileView: View {
    @EnvironmentObject var userSettings: UserSettings
    @State private var babyName = ""
    @State private var birthDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("欢迎使用宝宝出行助手") {
                    Text("首先让我们了解一下宝宝的信息，这样我们才能为您提供准确的出行建议。")
                        .foregroundColor(.secondary)
                }
                
                Section("宝宝信息") {
                    TextField("宝宝姓名（可选）", text: $babyName)
                    
                    DatePicker(
                        "出生日期",
                        selection: $birthDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                }
                
                Section {
                    let ageText = calculateAgeText(from: birthDate)
                    HStack {
                        Text("当前年龄")
                        Spacer()
                        Text(ageText)
                            .foregroundColor(.secondary)
                    }
                    
                    let category = BabyProfile(birthDate: birthDate).ageCategory
                    HStack {
                        Text("风险等级调整")
                        Spacer()
                        Text(category.description)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section {
                    Button("完成设置") {
                        let profile = BabyProfile(birthDate: birthDate, name: babyName)
                        userSettings.saveBabyProfile(profile)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("欢迎")
        }
    }
    
    private func calculateAgeText(from birthDate: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        let components = calendar.dateComponents([.year, .month, .day], from: birthDate, to: now)
        
        if let years = components.year, years > 0 {
            if let months = components.month, months > 0 {
                return "\(years) 岁 \(months) 个月"
            }
            return "\(years) 岁"
        } else if let months = components.month, months > 0 {
            if let days = components.day, days > 0 {
                return "\(months) 个月 \(days) 天"
            }
            return "\(months) 个月"
        } else if let days = components.day, days > 0 {
            return "\(days) 天"
        } else {
            return "今天出生"
        }
    }
}

struct SetupProfileView_Previews: PreviewProvider {
    static var previews: some View {
        SetupProfileView()
            .environmentObject(UserSettings.shared)
    }
}
