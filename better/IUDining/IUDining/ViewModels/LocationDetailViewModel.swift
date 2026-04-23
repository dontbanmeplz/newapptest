//
//  LocationDetailViewModel.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation

@MainActor
@Observable
class LocationDetailViewModel {
    var menusByStation: [String: [FoodItem]] = [:]
    var stationOrder: [String] = []
    var isLoading = false
    var errorMessage: String?

    private let service = NutrisliceService.shared

    /// Fetch today's menus for all menu types/stations at a location
    func loadMenus(for location: DiningLocation) async {
        guard let menuTypes = location.activeMenuTypes, !menuTypes.isEmpty else {
            return
        }

        isLoading = true
        errorMessage = nil

        var allStations: [String: [FoodItem]] = [:]
        var order: [String] = []

        let todayString = todayDateString()
        let fetchService = self.service

        await withTaskGroup(of: (String, [FoodItem]).self) { group in
            for menuType in menuTypes {
                group.addTask {
                    do {
                        let weekResponse = try await fetchService.fetchMenuWeek(
                            schoolId: location.id,
                            menuTypeId: menuType.id,
                            date: .now
                        )

                        // Find today's menu in the week response
                        if let todayMenu = weekResponse.days.first(where: { $0.date == todayString }) {
                            let foods = todayMenu.menuItems?
                                .compactMap { $0.food }
                                ?? []
                            return (menuType.name, foods)
                        }

                        // If no exact date match, try the first day that has items
                        if let firstDay = weekResponse.days.first(where: { !($0.menuItems ?? []).isEmpty }) {
                            let foods = firstDay.menuItems?
                                .compactMap { $0.food }
                                ?? []
                            return (menuType.name, foods)
                        }

                        return (menuType.name, [])
                    } catch {
                        // If one station fails, still show others
                        return (menuType.name, [])
                    }
                }
            }

            for await (stationName, items) in group {
                if !items.isEmpty {
                    allStations[stationName] = items
                    order.append(stationName)
                }
            }
        }

        stationOrder = order.sorted()
        menusByStation = allStations
        isLoading = false
    }

    private nonisolated func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
