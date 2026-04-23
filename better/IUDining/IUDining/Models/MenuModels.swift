//
//  MenuModels.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation

// MARK: - Digest Menu (lightweight)

struct MenuDigest: Codable {
    let date: String
    let menuItems: [String]?
    let holidayText: String?

    enum CodingKeys: String, CodingKey {
        case date
        case menuItems = "menu_items"
        case holidayText = "holiday_text"
    }
}

// MARK: - Full Menu Week Response

struct MenuWeekResponse: Codable {
    let startDate: String?
    let menuTypeId: String?
    let days: [MenuDay]

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case menuTypeId = "menu_type_id"
        case days
    }
}

struct MenuDay: Codable, Identifiable {
    var id: String { date ?? UUID().uuidString }
    let date: String?
    let menuItems: [FullMenuItem]?

    enum CodingKeys: String, CodingKey {
        case date
        case menuItems = "menu_items"
    }
}

struct FullMenuItem: Codable, Identifiable {
    let id: Int
    let position: Int?
    let isSectionTitle: Bool?
    let text: String?
    let food: FoodItem?
    let stationId: Int?
    let isStationHeader: Bool?
    let price: Double?

    enum CodingKeys: String, CodingKey {
        case id, position, text, food, price
        case isSectionTitle = "is_section_title"
        case stationId = "station_id"
        case isStationHeader = "is_station_header"
    }
}

struct FoodItem: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let ingredients: String?
    let foodCategory: String?
    let price: Double?
    let roundedNutritionInfo: NutritionInfo?
    let servingSizeInfo: ServingSizeInfo?
    let icons: FoodIcons?

    enum CodingKeys: String, CodingKey {
        case id, name, description, ingredients, price, icons
        case foodCategory = "food_category"
        case roundedNutritionInfo = "rounded_nutrition_info"
        case servingSizeInfo = "serving_size_info"
    }
}

struct NutritionInfo: Codable {
    let calories: Double?
    let gFat: Double?
    let gCarbs: Double?
    let gProtein: Double?
    let mgSodium: Double?
    let gFiber: Double?
    let gSugar: Double?

    enum CodingKeys: String, CodingKey {
        case calories
        case gFat = "g_fat"
        case gCarbs = "g_carbs"
        case gProtein = "g_protein"
        case mgSodium = "mg_sodium"
        case gFiber = "g_fiber"
        case gSugar = "g_sugar"
    }
}

struct ServingSizeInfo: Codable {
    let servingSizeAmount: String?
    let servingSizeUnit: String?

    enum CodingKeys: String, CodingKey {
        case servingSizeAmount = "serving_size_amount"
        case servingSizeUnit = "serving_size_unit"
    }
}

struct FoodIcons: Codable {
    let foodIcons: [FoodIcon]?

    enum CodingKeys: String, CodingKey {
        case foodIcons = "food_icons"
    }
}

struct FoodIcon: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let customIconUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case customIconUrl = "custom_icon_url"
    }
}

// MARK: - Parsed Station (for UI display)

struct MenuStation: Identifiable {
    let id: Int
    let name: String
    var items: [FoodItem]
}

extension MenuDay {
    /// Parse the flat menu items list into grouped stations
    var stations: [MenuStation] {
        guard let menuItems else { return [] }

        var result: [MenuStation] = []
        var currentStation: MenuStation?

        for item in menuItems {
            if item.isStationHeader == true || item.isSectionTitle == true {
                // Save previous station
                if let station = currentStation, !station.items.isEmpty {
                    result.append(station)
                }
                currentStation = MenuStation(
                    id: item.stationId ?? item.id,
                    name: item.text ?? "Menu",
                    items: []
                )
            } else if let food = item.food {
                if currentStation != nil {
                    currentStation?.items.append(food)
                } else {
                    // No station header yet, create a default
                    currentStation = MenuStation(id: 0, name: "Menu", items: [food])
                }
            }
        }

        // Don't forget the last station
        if let station = currentStation, !station.items.isEmpty {
            result.append(station)
        }

        return result
    }
}
