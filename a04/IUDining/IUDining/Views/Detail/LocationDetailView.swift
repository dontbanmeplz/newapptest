//
//  LocationDetailView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI

/// Detail view for a single dining location. Displays the location's
/// address, current open/closed status with next transition time,
/// full weekly operating hours, and today's menu grouped by station.
struct LocationDetailView: View {
    /// The dining location to display details for.
    let location: DiningLocation

    @State private var viewModel = LocationDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                headerSection

                // Status
                statusSection

                // Weekly Hours
                hoursSection

                // Menu
                if location.hasMenuData {
                    menuSection
                } else {
                    noneAvailableSection
                }
            }
            .padding()
        }
        .navigationTitle(location.name)
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.loadMenus(for: location)
        }
    }

    // MARK: - Header

    /// Displays the location's address with a map pin icon.
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !location.address.isEmpty {
                Label(location.address, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Status

    /// Displays the current open/closed status with a colored indicator
    /// and the next transition time (e.g. "Closes at 9:00 PM").
    private var statusSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Circle()
                    .fill(location.isOpen() ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(location.isOpen() ? "Currently Open" : "Currently Closed")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }

            if let transition = location.nextTransition() {
                Text("\(transition.label) at \(transition.time, style: .time)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hours

    /// Displays the full weekly operating hours schedule with the
    /// current day highlighted in bold.
    private var hoursSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly Hours")
                .font(.title3)
                .fontWeight(.bold)

            VStack(spacing: 6) {
                ForEach(location.weeklyHours, id: \.dayName) { day in
                    HStack {
                        Text(day.dayName)
                            .frame(width: 100, alignment: .leading)
                            .fontWeight(isCurrentDay(day.dayName) ? .bold : .regular)

                        if day.enabled {
                            Text("\(formatTime(day.start)) - \(formatTime(day.end))")
                                .foregroundStyle(isCurrentDay(day.dayName) ? .primary : .secondary)
                        } else {
                            Text("Closed")
                                .foregroundStyle(.red)
                        }

                        Spacer()
                    }
                    .font(.subheadline)

                    if day.dayName != "Sunday" {
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Menu

    /// Displays today's menu items grouped by station. Shows a loading
    /// indicator while data is being fetched, or a message if no items
    /// are available.
    private var menuSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today's Menu")
                .font(.title3)
                .fontWeight(.bold)

            if viewModel.isLoading {
                HStack {
                    ProgressView()
                    Text("Loading menus...")
                        .foregroundStyle(.secondary)
                }
                .padding()
            } else if viewModel.stationOrder.isEmpty {
                // TODO: Display menu items once LocationDetailViewModel
                // implements concurrent fetching via withTaskGroup.
                Text("No menu items available for today.")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(viewModel.stationOrder, id: \.self) { stationName in
                    if let items = viewModel.menusByStation[stationName] {
                        stationSection(name: stationName, items: items)
                    }
                }
            }
        }
    }

    /// Displays a single menu station with its food items, calorie counts,
    /// and dietary icon badges.
    ///
    /// - Parameters:
    ///   - name: The station name (e.g. "Grill", "Salad Bar").
    ///   - items: The food items available at this station.
    /// - Returns: A view displaying the station's food items.
    private func stationSection(name: String, items: [FoodItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.headline)
                .padding(.top, 4)

            VStack(spacing: 0) {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline)

                            Spacer()

                            // TODO: Display calorie count from nutrition info
                            // once menu data loading is implemented.
                            if let cal = item.roundedNutritionInfo?.calories {
                                Text("\(Int(cal)) cal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // TODO: Display dietary/allergen icon badges (vegan,
                        // vegetarian, gluten, etc.) with color-coded capsules
                        // once menu data loading is implemented.
                        if let icons = item.icons?.foodIcons, !icons.isEmpty {
                            HStack(spacing: 4) {
                                ForEach(icons) { icon in
                                    Text(icon.name)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(iconColor(for: icon.slug).opacity(0.15))
                                        .foregroundStyle(iconColor(for: icon.slug))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)

                    if items.last?.id != item.id {
                        Divider()
                            .padding(.leading, 12)
                    }
                }
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    /// Placeholder section shown when a location has no menu data available
    /// (e.g. hardcoded campus cafes not in the Nutrislice API).
    private var noneAvailableSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Menu")
                .font(.title3)
                .fontWeight(.bold)

            Text("Menu information is not available for this location. Check the IU Dining website for details.")
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    /// Formats a time string from "HH:mm:ss" to a readable format like "7 AM" or "2:30 PM".
    ///
    /// - Parameter timeStr: A time string in "HH:mm:ss" format.
    /// - Returns: A formatted time string with AM/PM.
    private func formatTime(_ timeStr: String) -> String {
        let parts = timeStr.split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return timeStr }

        let period = hour >= 12 ? "PM" : "AM"
        let displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        if minute == 0 {
            return "\(displayHour) \(period)"
        }
        return "\(displayHour):\(String(format: "%02d", minute)) \(period)"
    }

    /// Checks whether the given day name matches today's day of the week.
    ///
    /// - Parameter dayName: A full day name (e.g. "Monday", "Tuesday").
    /// - Returns: True if the day name matches today.
    private func isCurrentDay(_ dayName: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: .now) == dayName
    }

    /// Returns a color associated with a dietary/allergen icon slug.
    ///
    /// - Parameter slug: The icon slug identifier (e.g. "vegan", "gluten").
    /// - Returns: A color representing the dietary category.
    private func iconColor(for slug: String) -> Color {
        switch slug {
        case "vegan": return .green
        case "vegetarian": return .mint
        case "gluten": return .orange
        case "milk": return .blue
        case "egg": return .yellow
        case "soy": return .brown
        case "pork": return .pink
        case "beef": return .red
        default: return .gray
        }
    }
}
