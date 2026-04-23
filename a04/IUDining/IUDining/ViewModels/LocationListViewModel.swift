//
//  LocationListViewModel.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation
import CoreLocation

/// View model for the dining locations list screen.
///
/// Manages fetching location data from the Nutrislice API, merging
/// in hardcoded campus cafes, and sorting by distance from the user.
@MainActor
@Observable
class LocationListViewModel {
    /// All loaded dining locations (API + hardcoded cafes).
    var locations: [DiningLocation] = []

    /// Whether location data is currently being fetched.
    var isLoading = false

    /// Error message if fetching fails, nil on success.
    var errorMessage: String?

    private let service = NutrisliceService.shared
    private let locationService = LocationService.shared

    /// Fetches dining locations from the Nutrislice API and appends
    /// hardcoded campus cafes. Falls back to hardcoded cafes only on error.
    func loadLocations() async {
        isLoading = true
        errorMessage = nil

        do {
            var apiLocations = try await service.fetchLocations()
            // Merge in hardcoded cafes
            apiLocations.append(contentsOf: DiningLocation.hardcodedCafes)
            locations = apiLocations
        } catch {
            errorMessage = "Failed to load dining locations: \(error.localizedDescription)"
            // Fall back to hardcoded cafes only
            locations = DiningLocation.hardcodedCafes
        }

        isLoading = false
    }

    /// Locations sorted by distance from the user (closest first).
    /// Falls back to alphabetical sorting if user location is unavailable.
    var sortedLocations: [DiningLocation] {
        guard let userLoc = locationService.userLocation else {
            return locations.sorted { $0.name < $1.name }
        }
        return locations.sorted {
            $0.distance(from: userLoc) < $1.distance(from: userLoc)
        }
    }

    /// The user's current GPS location, if available.
    var userLocation: CLLocation? {
        locationService.userLocation
    }
}
