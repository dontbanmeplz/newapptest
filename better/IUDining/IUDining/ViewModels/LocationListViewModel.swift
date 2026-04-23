//
//  LocationListViewModel.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation
import CoreLocation

@MainActor
@Observable
class LocationListViewModel {
    var locations: [DiningLocation] = []
    var isLoading = false
    var errorMessage: String?

    private let service = NutrisliceService.shared
    private let locationService = LocationService.shared

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

    /// Locations sorted by distance from user (closest first)
    var sortedLocations: [DiningLocation] {
        guard let userLoc = locationService.userLocation else {
            return locations.sorted { $0.name < $1.name }
        }
        return locations.sorted {
            $0.distance(from: userLoc) < $1.distance(from: userLoc)
        }
    }

    var userLocation: CLLocation? {
        locationService.userLocation
    }
}
