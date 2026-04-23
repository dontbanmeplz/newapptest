//
//  LocationDetailViewModel.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation

/// View model for the location detail screen. Manages fetching and
/// organizing daily menu data for a given dining location.
///
/// Menus are grouped by station name (e.g. "Grill", "Salad Bar") and
/// presented in alphabetical order to the detail view.
@MainActor
@Observable
class LocationDetailViewModel {
    /// Menu items grouped by station name.
    var menusByStation: [String: [FoodItem]] = [:]

    /// Sorted list of station names for display order.
    var stationOrder: [String] = []

    /// Whether menu data is currently being fetched.
    var isLoading = false

    /// Error message if menu loading fails, nil on success.
    var errorMessage: String?

    private let service = NutrisliceService.shared

    /// Fetch today's menus for all menu types/stations at a location.
    ///
    /// - Parameter location: The dining location to load menus for.
    func loadMenus(for location: DiningLocation) async {
        guard let menuTypes = location.activeMenuTypes, !menuTypes.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        // TODO: Implement concurrent menu fetching using withTaskGroup to
        // load all menu types in parallel. For each menu type, call
        // NutrisliceService.fetchMenuWeek(), find today's date in the
        // response, and extract FoodItem objects grouped by station.

        // TODO: Parse station headers from FullMenuItem entries where
        // isStationHeader or isSectionTitle is true to group food items
        // into their respective stations.

        // TODO: Handle per-station failures gracefully so that if one
        // menu type fails to load, the others still display correctly.

        isLoading = false
    }

    /// Returns today's date formatted as "yyyy-MM-dd" for API matching.
    ///
    /// - Returns: A date string in the format expected by the Nutrislice API.
    private nonisolated func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
