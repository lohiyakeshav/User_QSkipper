//
//  LocationManager.swift
//  QSkipper
//
//  Created by Keshav Lohiya on 27/03/25.
//

import Foundation
import CoreLocation
import SwiftUI

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationManager()
    
    private let locationManager = CLLocationManager()
    
    @Published var location: CLLocation?
    @Published var locationStatus: CLAuthorizationStatus?
    @Published var locationName: String = "Finding your location..."
    @Published var isLocationServiceAvailable: Bool = false
    @Published var error: String? = nil
    
    // Galgotias University coordinates (default location)
    let defaultLocation = CLLocation(
        latitude: AppConstants.defaultLatitude,
        longitude: AppConstants.defaultLongitude
    )
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        checkLocationServices()
    }
    
    func checkLocationServices() {
        if CLLocationManager.locationServicesEnabled() {
            setupLocationManager()
        } else {
            isLocationServiceAvailable = false
            error = "Location services are disabled"
        }
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    func requestLocation() {
        // Move authorization check to background thread
        Task {
            // Check existing status first
            let status = locationManager.authorizationStatus
            
            // Only request authorization if not determined yet
            if status == .notDetermined {
                // Jump to main thread to request authorization
                await MainActor.run {
                    locationManager.requestWhenInUseAuthorization()
                }
            } else if status == .authorizedWhenInUse || status == .authorizedAlways {
                // If already authorized, just request location
                await MainActor.run {
                    locationManager.requestLocation()
                }
            }
        }
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.locationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.isLocationServiceAvailable = true
                self.locationManager.startUpdatingLocation()
            case .denied, .restricted:
                self.isLocationServiceAvailable = false
                self.error = "Location access denied"
                // Use default location (Galgotias University)
                self.location = self.defaultLocation
                self.getPlaceName(for: self.defaultLocation)
            case .notDetermined:
                self.isLocationServiceAvailable = false
                self.locationManager.requestWhenInUseAuthorization()
            @unknown default:
                self.isLocationServiceAvailable = false
                self.error = "Unknown location authorization status"
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        DispatchQueue.main.async {
            self.location = location
            self.getPlaceName(for: location)
            self.locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.error = error.localizedDescription
            
            // If location cannot be determined, use default location (Galgotias University)
            self.location = self.defaultLocation
            self.getPlaceName(for: self.defaultLocation)
        }
    }
    
    func getPlaceName(for location: CLLocation) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            // Make sure we're on the main thread for all UI updates
            DispatchQueue.main.async {
                if let error = error {
                    self.error = error.localizedDescription
                    self.locationName = AppConstants.defaultLocation
                    return
                }
                
                if let placemark = placemarks?.first {
                    if let locality = placemark.locality, let subLocality = placemark.subLocality {
                        self.locationName = "\(subLocality), \(locality)"
                    } else if let locality = placemark.locality {
                        self.locationName = locality
                    } else if let name = placemark.name {
                        self.locationName = name
                    } else {
                        self.locationName = "Unknown location"
                    }
                } else {
                    self.locationName = "Unknown location"
                }
                
                // Check if we are near the default location (Galgotias University)
                if self.isNearDefaultLocation(location) {
                    self.locationName = AppConstants.defaultLocation
                }
            }
        }
    }
    
    // Check if the location is near Galgotias University (within 2 kilometers)
    func isNearDefaultLocation(_ location: CLLocation) -> Bool {
        let distance = location.distance(from: defaultLocation)
        // 2000 meters = 2 kilometers
        return distance <= 2000
    }
    
    // Check if food delivery service is available at the current location
    func isDeliveryServiceAvailable() -> Bool {
        guard let location = self.location else {
            return false
        }
        
        // For now, we'll just check if the location is near Galgotias University
        return isNearDefaultLocation(location)
    }
    
    // Use default location (Galgotias University)
    func useDefaultLocation() {
        self.location = defaultLocation
        self.locationName = AppConstants.defaultLocation
        self.isLocationServiceAvailable = true
    }
} 