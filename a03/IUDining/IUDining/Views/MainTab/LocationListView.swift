//
//  LocationListView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI

struct LocationListView: View {
    @State private var viewModel = LocationListViewModel()
    @State private var searchText = ""

    var filteredLocations: [DiningLocation] {
        let sorted = viewModel.sortedLocations
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.locations.isEmpty {
                    ProgressView("Loading dining locations...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.locations.isEmpty {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            Task { await viewModel.loadLocations() }
                        }
                    }
                } else {
                    List(filteredLocations) { location in
                        NavigationLink(value: location.id) {
                            LocationRowView(
                                location: location,
                                userLocation: viewModel.userLocation
                            )
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search dining locations")
                    .refreshable {
                        await viewModel.loadLocations()
                    }
                }
            }
            .navigationTitle("IU Dining")
            .navigationDestination(for: Int.self) { locationId in
                if let location = viewModel.locations.first(where: { $0.id == locationId }) {
                    LocationDetailView(location: location)
                }
            }
            .task {
                LocationService.shared.requestPermission()
                await viewModel.loadLocations()
            }
        }
    }
}
