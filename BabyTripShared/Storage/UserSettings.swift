//
//  UserSettings.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation
import Combine

public class UserSettings: ObservableObject {
    public static let shared = UserSettings()
    
    private let userDefaults = UserDefaults.standard
    
    @Published public private(set) var babyProfile: BabyProfile?
    @Published public private(set) var preferences: UserPreferences
    
    private let babyProfileKey = "BabyProfile"
    private let preferencesKey = "UserPreferences"
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        preferences = UserSettings.loadPreferences()
        loadProfile()
    }
    
    public func savePreferences(_ preferences: UserPreferences) {
        self.preferences = preferences
        do {
            let data = try JSONEncoder().encode(preferences)
            userDefaults.set(data, forKey: preferencesKey)
        } catch {
            print("Error saving user preferences: \(error)")
        }
    }
    
    private static func loadPreferences() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: "UserPreferences") else {
            return UserPreferences()
        }
        
        do {
            return try JSONDecoder().decode(UserPreferences.self, from: data)
        } catch {
            print("Error loading user preferences: \(error)")
            return UserPreferences()
        }
    }
    
    public func saveBabyProfile(_ profile: BabyProfile) {
        babyProfile = profile
        saveProfile()
    }
    
    public func hasProfile() -> Bool {
        return babyProfile != nil
    }
    
    private func saveProfile() {
        guard let profile = babyProfile else {
            userDefaults.removeObject(forKey: babyProfileKey)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(profile)
            userDefaults.set(data, forKey: babyProfileKey)
        } catch {
            print("Error saving baby profile: \(error)")
        }
    }
    
    private func loadProfile() {
        guard let data = userDefaults.data(forKey: babyProfileKey) else {
            return
        }
        
        do {
            let profile = try JSONDecoder().decode(BabyProfile.self, from: data)
            babyProfile = profile
        } catch {
            print("Error loading baby profile: \(error)")
        }
    }
}
