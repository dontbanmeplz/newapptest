//
//  ContentView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = LocationListViewModel()
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            LocationListView()
                .tabItem {
                    Label("Dining", systemImage: "fork.knife")
                }
                .tag(0)

            DiningMapView(locations: viewModel.sortedLocations)
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(1)

            DiningARView(locations: viewModel.sortedLocations)
                .tabItem {
                    Label("AR View", systemImage: "camera.viewfinder")
                }
                .tag(2)
        }
        .task {
            LocationService.shared.requestPermission()
            await viewModel.loadLocations()
        }
    }
}

#Preview {
    ContentView()
}
