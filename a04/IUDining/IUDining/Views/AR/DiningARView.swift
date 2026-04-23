//
//  DiningARView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI
import CoreLocation

/// Augmented reality view that will display nearby dining locations as
/// floating 3D billboard cards positioned in real-world directions.
///
/// Uses ARKit orientation tracking and RealityKit to render location markers
/// in the camera feed, with compass-based placement relative to the user.
struct DiningARView: View {
    /// Array of dining locations to display as AR markers.
    let locations: [DiningLocation]

    @State private var locationService = LocationService.shared

    var body: some View {
        NavigationStack {
            VStack {
                // TODO: Replace placeholder with ARViewContainer (UIViewRepresentable)
                // that bridges RealityKit's ARView into SwiftUI using
                // AROrientationTrackingConfiguration for 3DOF rotation tracking.
                Spacer()

                ContentUnavailableView(
                    "AR Coming Soon",
                    systemImage: "arkit",
                    description: Text("Augmented reality dining location markers will be displayed here in a future update.")
                )

                Spacer()

                // Bottom carousel showing nearest locations
                locationCarousel
                    .padding(.bottom, 8)
            }
            .navigationTitle("AR View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear {
                locationService.startHeading()
            }
            .onDisappear {
                locationService.stopUpdating()
                locationService.requestPermission()
                locationService.startUpdating()
            }
        }
    }

    // MARK: - Location Carousel

    /// Horizontal scrollable overlay showing the nearest dining locations
    /// with their name, open/closed status, and distance from the user.
    private var locationCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(nearestLocations) { location in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Circle()
                                .fill(location.isOpen() ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            Text(location.name)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }

                        Text(location.distanceString(from: locationService.userLocation))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Nearest Locations

    /// Returns the nearest dining locations sorted by distance from the user.
    /// Falls back to the first five locations if user location is unavailable.
    private var nearestLocations: [DiningLocation] {
        guard let userLoc = locationService.userLocation else {
            return Array(locations.prefix(5))
        }
        return locations
            .filter { $0.hasLocation }
            .sorted { $0.distance(from: userLoc) < $1.distance(from: userLoc) }
    }

    // MARK: - Stub Methods (Planned AR Functionality)

    // TODO: Implement ARViewContainer as a UIViewRepresentable that creates
    // an ARView with AROrientationTrackingConfiguration (3DOF orientation tracking).

    // TODO: Implement placeMarkers(in:userLocation:coordinator:) to compute
    // GPS bearing from user to each dining location, convert to AR scene
    // coordinates relative to initial compass heading, and place 3D anchors.

    // TODO: Implement buildBillboard(on:location:realDistance:) to create
    // RealityKit text meshes and panel entities for each location marker,
    // showing name, distance, and open/closed status with color coding.

    // TODO: Implement cluster detection and vertical stacking when multiple
    // locations overlap in angular direction (within ~15 degrees).

    // TODO: Implement per-frame billboard rotation via SceneEvents.Update
    // subscription to keep all billboard anchors facing the camera.

    // TODO: Implement bearingBetween(userLat:userLon:targetLat:targetLon:)
    // to calculate compass bearing between two GPS coordinates in radians.
}
