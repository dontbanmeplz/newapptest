//
//  NutrisliceService.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation

/// API client for the Nutrislice dining menu service.
///
/// Provides methods to fetch dining location data and menu information
/// from the Indiana University Nutrislice API endpoint.
@MainActor
@Observable
class NutrisliceService {
    /// Shared singleton instance used throughout the app.
    static let shared = NutrisliceService()

    /// Base URL for the Nutrislice API.
    private let baseURL = "https://indiana-dining.api.nutrislice.com"

    /// Configured URL session with custom timeout intervals.
    private let session: URLSession

    /// JSON decoder for parsing API responses.
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Fetch All Schools/Locations

    /// Fetches all dining locations (schools) from the Nutrislice API.
    ///
    /// - Returns: An array of `DiningLocation` objects decoded from the API response.
    /// - Throws: `NutrisliceError.invalidResponse` if the server returns a non-200 status.
    func fetchLocations() async throws -> [DiningLocation] {
        let url = URL(string: "\(baseURL)/menu/api/schools")!
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NutrisliceError.invalidResponse
        }

        return try decoder.decode([DiningLocation].self, from: data)
    }

    // MARK: - Fetch Digest Menu (lightweight item names)

    /// Fetches a lightweight digest menu for a specific date and menu type.
    ///
    /// - Parameters:
    ///   - schoolSlug: The URL slug identifying the school/dining location.
    ///   - menuTypeSlug: The URL slug identifying the menu type.
    ///   - date: The date to fetch the menu for (defaults to today).
    /// - Returns: A `MenuDigest` containing item names for the requested date.
    /// - Throws: `NutrisliceError.invalidResponse` if the server returns a non-200 status.
    func fetchMenuDigest(schoolSlug: String, menuTypeSlug: String, date: Date = .now) async throws -> MenuDigest {
        // TODO: Connect to LocationDetailViewModel to display daily menu summaries.
        let components = dateComponents(from: date)
        let url = URL(string: "\(baseURL)/menu/api/digest/school/\(schoolSlug)/menu-type/\(menuTypeSlug)/date/\(components.year)/\(components.month)/\(components.day)")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NutrisliceError.invalidResponse
        }

        return try decoder.decode(MenuDigest.self, from: data)
    }

    // MARK: - Fetch Full Menu Week (detailed with nutrition)

    /// Fetches the full weekly menu with nutrition details for a given location and menu type.
    ///
    /// - Parameters:
    ///   - schoolId: The numeric ID of the school/dining location.
    ///   - menuTypeId: The numeric ID of the menu type.
    ///   - date: A date within the desired week (defaults to today).
    /// - Returns: A `MenuWeekResponse` containing daily menus with full nutrition data.
    /// - Throws: `NutrisliceError.invalidResponse` if the server returns a non-200 status.
    func fetchMenuWeek(schoolId: Int, menuTypeId: Int, date: Date = .now) async throws -> MenuWeekResponse {
        // TODO: Connect to LocationDetailViewModel to display detailed menu
        // items with nutrition info and dietary icons in the detail view.
        let components = dateComponents(from: date)
        let url = URL(string: "\(baseURL)/menu/api/weeks/school/\(schoolId)/menu-type/\(menuTypeId)/\(components.year)/\(components.month)/\(components.day)")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NutrisliceError.invalidResponse
        }

        return try decoder.decode(MenuWeekResponse.self, from: data)
    }

    // MARK: - Helpers

    /// Extracts year, month, and day components from a date for URL construction.
    ///
    /// - Parameter date: The date to extract components from.
    /// - Returns: A tuple of (year, month, day) strings.
    private func dateComponents(from date: Date) -> (year: String, month: String, day: String) {
        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: date))
        let month = String(calendar.component(.month, from: date))
        let day = String(calendar.component(.day, from: date))
        return (year, month, day)
    }
}

/// Errors that can occur when communicating with the Nutrislice API.
enum NutrisliceError: LocalizedError {
    /// The server returned an unexpected or non-200 HTTP status code.
    case invalidResponse

    /// The response data could not be decoded into the expected model.
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Failed to get a valid response from the server."
        case .decodingFailed: return "Failed to parse server data."
        }
    }
}
