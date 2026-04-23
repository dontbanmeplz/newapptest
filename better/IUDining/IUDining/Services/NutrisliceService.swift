//
//  NutrisliceService.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation

/// API client for the Nutrislice dining menu service
@MainActor
@Observable
class NutrisliceService {
    static let shared = NutrisliceService()

    private let baseURL = "https://indiana-dining.api.nutrislice.com"
    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
    }

    // MARK: - Fetch All Schools/Locations

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

    func fetchMenuDigest(schoolSlug: String, menuTypeSlug: String, date: Date = .now) async throws -> MenuDigest {
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

    func fetchMenuWeek(schoolId: Int, menuTypeId: Int, date: Date = .now) async throws -> MenuWeekResponse {
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

    private func dateComponents(from date: Date) -> (year: String, month: String, day: String) {
        let calendar = Calendar.current
        let year = String(calendar.component(.year, from: date))
        let month = String(calendar.component(.month, from: date))
        let day = String(calendar.component(.day, from: date))
        return (year, month, day)
    }
}

enum NutrisliceError: LocalizedError {
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Failed to get a valid response from the server."
        case .decodingFailed: return "Failed to parse server data."
        }
    }
}
