//
//  LocationManager.swift
//  BabyTripShared
//
//  Created by BabyTrip Project
//

import Foundation
import CoreLocation

public class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    
    @Published public var location: CLLocation?
    #if !os(macOS)
    @Published public var authorizationStatus: CLAuthorizationStatus?
    #endif
    @Published public var error: Error?
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
    }
    
    public func requestLocation() {
        #if !os(macOS)
        locationManager.requestWhenInUseAuthorization()
        #endif
        locationManager.requestLocation()
    }
    
    #if !os(macOS)
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse {
            manager.requestLocation()
        }
    }
    #endif
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
        error = nil
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error
    }
}
