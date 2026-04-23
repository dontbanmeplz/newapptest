//
//  LocationService.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation
import CoreLocation

/// Singleton service that wraps `CLLocationManager` for user location
/// and compass heading updates.
///
/// Publishes the user's current GPS location, compass heading, and
/// authorization status. Used by views and view models to compute
/// distances, sort locations, and orient AR content.
@MainActor
@Observable
class LocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    /// Shared singleton instance used throughout the app.
    static let shared = LocationService()

    private let manager = CLLocationManager()

    /// The user's most recent GPS location, or nil if unavailable.
    var userLocation: CLLocation?

    /// The device's most recent compass heading, or nil if unavailable.
    var heading: CLHeading?

    /// The current location authorization status.
    var authorizationStatus: CLAuthorizationStatus = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 10 // Update every 10 meters
        manager.headingFilter = 5   // Update every 5 degrees
    }

    /// Requests when-in-use location authorization from the user.
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    /// Starts receiving GPS location updates.
    func startUpdating() {
        manager.startUpdatingLocation()
    }

    /// Starts receiving compass heading updates, if available on this device.
    func startHeading() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    /// Stops all location and heading updates to conserve battery.
    func stopUpdating() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        heading = newHeading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        default:
            break
        }
    }
}
