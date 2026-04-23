//
//  LocationDetailView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI

struct LocationDetailView: View {
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

                            if let cal = item.roundedNutritionInfo?.calories {
                                Text("\(Int(cal)) cal")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Dietary icons
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

    private func isCurrentDay(_ dayName: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: .now) == dayName
    }

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
