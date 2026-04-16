//
//  DiningLocation.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import Foundation
import CoreLocation

// MARK: - Nutrislice API Response Models

struct DiningLocation: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let address: String
    let logo: String?
    let heroImage: String?
    let timezone: String?
    let geolocation: Geolocation?
    let operatingStatus: String?

    // Hours per day
    let monEnabled: Bool
    let monStart: String
    let monEnd: String
    let tueEnabled: Bool
    let tueStart: String
    let tueEnd: String
    let wedEnabled: Bool
    let wedStart: String
    let wedEnd: String
    let thuEnabled: Bool
    let thuStart: String
    let thuEnd: String
    let friEnabled: Bool
    let friStart: String
    let friEnd: String
    let satEnabled: Bool
    let satStart: String
    let satEnd: String
    let sunEnabled: Bool
    let sunStart: String
    let sunEnd: String

    let activeMenuTypes: [MenuType]?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, address, logo, timezone, geolocation
        case heroImage = "hero_image"
        case operatingStatus = "operating_status"
        case monEnabled = "mon_enabled"
        case monStart = "mon_start"
        case monEnd = "mon_end"
        case tueEnabled = "tue_enabled"
        case tueStart = "tue_start"
        case tueEnd = "tue_end"
        case wedEnabled = "wed_enabled"
        case wedStart = "wed_start"
        case wedEnd = "wed_end"
        case thuEnabled = "thu_enabled"
        case thuStart = "thu_start"
        case thuEnd = "thu_end"
        case friEnabled = "fri_enabled"
        case friStart = "fri_start"
        case friEnd = "fri_end"
        case satEnabled = "sat_enabled"
        case satStart = "sat_start"
        case satEnd = "sat_end"
        case sunEnabled = "sun_enabled"
        case sunStart = "sun_start"
        case sunEnd = "sun_end"
        case activeMenuTypes = "active_menu_types"
    }
}

struct Geolocation: Codable {
    let latitude: Double
    let longitude: Double
}

struct MenuType: Codable, Identifiable {
    let id: Int
    let name: String
    let slug: String
    let urls: MenuTypeURLs?

    enum CodingKeys: String, CodingKey {
        case id, name, slug, urls
    }
}

struct MenuTypeURLs: Codable {
    let digestMenuByDateApiUrlTemplate: String?
    let digestMenuByWeekApiUrlTemplate: String?

    enum CodingKeys: String, CodingKey {
        case digestMenuByDateApiUrlTemplate = "digest_menu_by_date_api_url_template"
        case digestMenuByWeekApiUrlTemplate = "digest_menu_by_week_api_url_template"
    }
}

// MARK: - Computed Helpers

extension DiningLocation {
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: geolocation?.latitude ?? 0,
            longitude: geolocation?.longitude ?? 0
        )
    }

    var clLocation: CLLocation {
        CLLocation(
            latitude: geolocation?.latitude ?? 0,
            longitude: geolocation?.longitude ?? 0
        )
    }

    var hasLocation: Bool {
        geolocation != nil
    }

    func distance(from userLocation: CLLocation) -> CLLocationDistance {
        userLocation.distance(from: clLocation)
    }

    /// Returns formatted distance string
    func distanceString(from userLocation: CLLocation?) -> String {
        guard let userLocation else { return "" }
        let meters = distance(from: userLocation)
        let miles = meters / 1609.34
        if miles < 0.1 {
            let feet = Int(meters * 3.28084)
            return "\(feet) ft"
        } else {
            return String(format: "%.1f mi", miles)
        }
    }

    // MARK: - Hours Logic

    struct DayHours {
        let dayName: String
        let enabled: Bool
        let start: String
        let end: String
    }

    var weeklyHours: [DayHours] {
        [
            DayHours(dayName: "Monday", enabled: monEnabled, start: monStart, end: monEnd),
            DayHours(dayName: "Tuesday", enabled: tueEnabled, start: tueStart, end: tueEnd),
            DayHours(dayName: "Wednesday", enabled: wedEnabled, start: wedStart, end: wedEnd),
            DayHours(dayName: "Thursday", enabled: thuEnabled, start: thuStart, end: thuEnd),
            DayHours(dayName: "Friday", enabled: friEnabled, start: friStart, end: friEnd),
            DayHours(dayName: "Saturday", enabled: satEnabled, start: satStart, end: satEnd),
            DayHours(dayName: "Sunday", enabled: sunEnabled, start: sunStart, end: sunEnd),
        ]
    }

    /// Check if currently open based on day of week and time
    func isOpen(at date: Date = .now) -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date) // 1=Sun, 2=Mon, ...
        let hours = hoursForWeekday(weekday)

        guard hours.enabled else { return false }

        guard let openTime = timeFromString(hours.start, on: date),
              let closeTime = timeFromString(hours.end, on: date) else { return false }

        return date >= openTime && date < closeTime
    }

    /// Returns the next open or close event
    func nextTransition(from date: Date = .now) -> (label: String, time: Date)? {
        let calendar = Calendar.current

        if isOpen(at: date) {
            // Currently open -> find close time today
            let weekday = calendar.component(.weekday, from: date)
            let hours = hoursForWeekday(weekday)
            if let closeTime = timeFromString(hours.end, on: date) {
                return ("Closes", closeTime)
            }
        } else {
            // Currently closed -> find next open time
            for dayOffset in 0..<7 {
                guard let futureDate = calendar.date(byAdding: .day, value: dayOffset, to: date) else { continue }
                let weekday = calendar.component(.weekday, from: futureDate)
                let hours = hoursForWeekday(weekday)

                guard hours.enabled else { continue }

                if let openTime = timeFromString(hours.start, on: futureDate) {
                    if openTime > date {
                        return ("Opens", openTime)
                    }
                }
            }
        }
        return nil
    }

    private func hoursForWeekday(_ weekday: Int) -> DayHours {
        switch weekday {
        case 1: return weeklyHours[6] // Sunday
        case 2: return weeklyHours[0] // Monday
        case 3: return weeklyHours[1] // Tuesday
        case 4: return weeklyHours[2] // Wednesday
        case 5: return weeklyHours[3] // Thursday
        case 6: return weeklyHours[4] // Friday
        case 7: return weeklyHours[5] // Saturday
        default: return weeklyHours[0]
        }
    }

    private func timeFromString(_ timeStr: String, on date: Date) -> Date? {
        let calendar = Calendar.current
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}

// MARK: - Static Cafe Data

extension DiningLocation {
    /// Hardcoded cafes that aren't in the Nutrislice API
    static let hardcodedCafes: [DiningLocation] = [
        DiningLocation(
            id: 900001, name: "Ballantine Cafe", slug: "ballantine-cafe",
            address: "1020 E. Kirkwood Ave, Bloomington, IN 47405",
            logo: nil, heroImage: nil, timezone: "US/Eastern",
            geolocation: Geolocation(latitude: 39.1680, longitude: -86.5230),
            operatingStatus: "open",
            monEnabled: true, monStart: "07:30:00", monEnd: "16:00:00",
            tueEnabled: true, tueStart: "07:30:00", tueEnd: "16:00:00",
            wedEnabled: true, wedStart: "07:30:00", wedEnd: "16:00:00",
            thuEnabled: true, thuStart: "07:30:00", thuEnd: "16:00:00",
            friEnabled: true, friStart: "07:30:00", friEnd: "16:00:00",
            satEnabled: false, satStart: "00:00:00", satEnd: "00:00:00",
            sunEnabled: false, sunStart: "00:00:00", sunEnd: "00:00:00",
            activeMenuTypes: nil
        ),
        DiningLocation(
            id: 900002, name: "Eigenmann Cafe", slug: "eigenmann-cafe",
            address: "1900 E. 10th St, Bloomington, IN 47406",
            logo: nil, heroImage: nil, timezone: "US/Eastern",
            geolocation: Geolocation(latitude: 39.1748, longitude: -86.5103),
            operatingStatus: "open",
            monEnabled: true, monStart: "10:00:00", monEnd: "22:00:00",
            tueEnabled: true, tueStart: "10:00:00", tueEnd: "22:00:00",
            wedEnabled: true, wedStart: "10:00:00", wedEnd: "22:00:00",
            thuEnabled: true, thuStart: "10:00:00", thuEnd: "22:00:00",
            friEnabled: true, friStart: "10:00:00", friEnd: "22:00:00",
            satEnabled: true, satStart: "10:00:00", satEnd: "22:00:00",
            sunEnabled: true, sunStart: "10:00:00", sunEnd: "22:00:00",
            activeMenuTypes: nil
        ),
        DiningLocation(
            id: 900003, name: "Education Cafe", slug: "education-cafe",
            address: "201 N. Rose Ave, Bloomington, IN 47405",
            logo: nil, heroImage: nil, timezone: "US/Eastern",
            geolocation: Geolocation(latitude: 39.1720, longitude: -86.5230),
            operatingStatus: "open",
            monEnabled: true, monStart: "07:30:00", monEnd: "15:00:00",
            tueEnabled: true, tueStart: "07:30:00", tueEnd: "15:00:00",
            wedEnabled: true, wedStart: "07:30:00", wedEnd: "15:00:00",
            thuEnabled: true, thuStart: "07:30:00", thuEnd: "15:00:00",
            friEnabled: true, friStart: "07:30:00", friEnd: "15:00:00",
            satEnabled: false, satStart: "00:00:00", satEnd: "00:00:00",
            sunEnabled: false, sunStart: "00:00:00", sunEnd: "00:00:00",
            activeMenuTypes: nil
        ),
        DiningLocation(
            id: 900004, name: "Hodge Cafe", slug: "hodge-cafe",
            address: "1309 E. 10th St, Bloomington, IN 47405",
            logo: nil, heroImage: nil, timezone: "US/Eastern",
            geolocation: Geolocation(latitude: 39.1738, longitude: -86.5165),
            operatingStatus: "open",
            monEnabled: true, monStart: "07:30:00", monEnd: "17:00:00",
            tueEnabled: true, tueStart: "07:30:00", tueEnd: "17:00:00",
            wedEnabled: true, wedStart: "07:30:00", wedEnd: "17:00:00",
            thuEnabled: true, thuStart: "07:30:00", thuEnd: "17:00:00",
            friEnabled: true, friStart: "07:30:00", friEnd: "17:00:00",
            satEnabled: false, satStart: "00:00:00", satEnd: "00:00:00",
            sunEnabled: false, sunStart: "00:00:00", sunEnd: "00:00:00",
            activeMenuTypes: nil
        ),
        DiningLocation(
            id: 900005, name: "Wells Library Bookmarket", slug: "bookmarket",
            address: "1320 E. 10th St, Bloomington, IN 47405",
            logo: nil, heroImage: nil, timezone: "US/Eastern",
            geolocation: Geolocation(latitude: 39.1741, longitude: -86.5152),
            operatingStatus: "open",
            monEnabled: true, monStart: "08:00:00", monEnd: "20:00:00",
            tueEnabled: true, tueStart: "08:00:00", tueEnd: "20:00:00",
            wedEnabled: true, wedStart: "08:00:00", wedEnd: "20:00:00",
            thuEnabled: true, thuStart: "08:00:00", thuEnd: "20:00:00",
            friEnabled: true, friStart: "08:00:00", friEnd: "17:00:00",
            satEnabled: false, satStart: "00:00:00", satEnd: "00:00:00",
            sunEnabled: false, sunStart: "00:00:00", sunEnd: "00:00:00",
            activeMenuTypes: nil
        ),
    ]

    /// Whether this is a hardcoded cafe (no live menu data)
    var isCafe: Bool {
        id >= 900000
    }

    /// Whether this location has menu data available
    var hasMenuData: Bool {
        !(activeMenuTypes ?? []).isEmpty
    }
}
