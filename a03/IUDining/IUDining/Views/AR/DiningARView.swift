//
//  DiningARView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI
import ARKit
import RealityKit
import CoreLocation

struct DiningARView: View {
    let locations: [DiningLocation]

    @State private var locationService = LocationService.shared
    @State private var arError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if ARWorldTrackingConfiguration.isSupported {
                    ARViewContainer(
                        locations: locations,
                        userLocation: locationService.userLocation
                    )
                    .ignoresSafeArea(.container, edges: .top)

                    // Overlay with location cards
                    VStack {
                        Spacer()
                        locationCarousel
                            .padding(.bottom, 8)
                    }
                } else {
                    ContentUnavailableView(
                        "AR Not Available",
                        systemImage: "camera.badge.ellipsis",
                        description: Text("This device does not support AR. Try the Map tab instead.")
                    )
                }
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

    private var nearestLocations: [DiningLocation] {
        guard let userLoc = locationService.userLocation else {
            return Array(locations.prefix(5))
        }
        return locations
            .filter { $0.hasLocation }
            .sorted { $0.distance(from: userLoc) < $1.distance(from: userLoc) }
    }
}

// MARK: - AR View Container (UIViewRepresentable)

struct ARViewContainer: UIViewRepresentable {
    let locations: [DiningLocation]
    let userLocation: CLLocation?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        // gravityAndHeading aligns ARKit's -Z axis to compass north automatically
        config.worldAlignment = .gravityAndHeading
        arView.session.run(config)

        context.coordinator.arView = arView
        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        guard let userLoc = userLocation else { return }

        // Only rebuild markers if user moved significantly (>15m) or first time
        if let lastLoc = context.coordinator.lastPlacedLocation {
            let moved = userLoc.distance(from: lastLoc)
            if moved < 15 { return }
        }

        context.coordinator.lastPlacedLocation = userLoc
        placeMarkers(in: arView, userLocation: userLoc)
    }

    private func placeMarkers(in arView: ARView, userLocation: CLLocation) {
        // Remove old markers
        arView.scene.anchors.removeAll()

        for location in locations where location.hasLocation {
            let realDistance = Float(userLocation.distance(from: location.clLocation))

            // Skip locations further than 5km
            guard realDistance < 5000 else { continue }

            // Calculate bearing from user to target (radians, 0 = north, clockwise)
            let bearing = bearingBetween(
                userLat: userLocation.coordinate.latitude,
                userLon: userLocation.coordinate.longitude,
                targetLat: location.coordinate.latitude,
                targetLon: location.coordinate.longitude
            )

            // With gravityAndHeading, ARKit -Z = north, +X = east
            // Place all markers close (5-8m) so they're large and readable on screen
            // Spread them out by distance tier so they don't overlap
            let arDistance: Float = 5.0 + min(realDistance / 1000.0, 1.0) * 3.0 // 5m to 8m

            // Convert bearing + distance to cartesian
            let x = arDistance * sin(bearing)
            let z = -arDistance * cos(bearing)
            let y: Float = 1.0 // Slightly above eye level

            let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))

            // -- Background panel for readability --
            let isOpen = location.isOpen()
            let panelColor: UIColor = isOpen
                ? UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.88)
                : UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.88)

            // Build name text first to measure it
            let nameText = location.name
            let nameMesh = MeshResource.generateText(
                nameText,
                extrusionDepth: 0.005,
                font: .boldSystemFont(ofSize: 0.22),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let nameEntity = ModelEntity(
                mesh: nameMesh,
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )

            // Distance text
            let distStr: String
            if realDistance < 1000 {
                distStr = String(format: "%.0f m away", realDistance)
            } else {
                distStr = String(format: "%.1f mi away", realDistance / 1609.34)
            }
            let distMesh = MeshResource.generateText(
                distStr,
                extrusionDepth: 0.005,
                font: .systemFont(ofSize: 0.14),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let distEntity = ModelEntity(
                mesh: distMesh,
                materials: [SimpleMaterial(color: UIColor(white: 0.9, alpha: 1.0), isMetallic: false)]
            )

            // Status text
            let statusStr = isOpen ? "Open Now" : "Closed"
            let statusMesh = MeshResource.generateText(
                statusStr,
                extrusionDepth: 0.005,
                font: .boldSystemFont(ofSize: 0.12),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let statusColor: UIColor = isOpen
                ? UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0)
                : UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
            let statusEntity = ModelEntity(
                mesh: statusMesh,
                materials: [SimpleMaterial(color: statusColor, isMetallic: false)]
            )

            // Measure text widths to size the panel
            let nameBounds = nameEntity.visualBounds(relativeTo: nil)
            let distBounds = distEntity.visualBounds(relativeTo: nil)
            let statusBounds = statusEntity.visualBounds(relativeTo: nil)

            let maxTextWidth = max(nameBounds.extents.x, max(distBounds.extents.x, statusBounds.extents.x))
            let panelWidth = maxTextWidth + 0.3
            let panelHeight: Float = 0.7
            let panelDepth: Float = 0.02

            // Background panel
            let panelMesh = MeshResource.generateBox(size: SIMD3<Float>(panelWidth, panelHeight, panelDepth), cornerRadius: 0.05)
            let panelEntity = ModelEntity(
                mesh: panelMesh,
                materials: [SimpleMaterial(color: panelColor, isMetallic: false)]
            )
            anchor.addChild(panelEntity)

            // Position text on top of panel (slightly in front)
            let frontZ: Float = panelDepth / 2 + 0.005

            // Name at top
            nameEntity.position = SIMD3<Float>(
                -nameBounds.extents.x / 2,
                0.12,
                frontZ
            )
            anchor.addChild(nameEntity)

            // Distance in middle
            distEntity.position = SIMD3<Float>(
                -distBounds.extents.x / 2,
                -0.05,
                frontZ
            )
            anchor.addChild(distEntity)

            // Status at bottom
            statusEntity.position = SIMD3<Float>(
                -statusBounds.extents.x / 2,
                -0.22,
                frontZ
            )
            anchor.addChild(statusEntity)

            // Small colored dot indicator at top-left of panel
            let dotSize: Float = 0.06
            let dot = ModelEntity(
                mesh: .generateSphere(radius: dotSize),
                materials: [SimpleMaterial(color: isOpen ? .systemGreen : .systemRed, isMetallic: false)]
            )
            dot.position = SIMD3<Float>(-panelWidth / 2 + 0.1, 0.22, frontZ)
            anchor.addChild(dot)

            arView.scene.addAnchor(anchor)
        }
    }

    /// Calculate bearing from point A to point B (returns radians, 0 = north, clockwise)
    private func bearingBetween(userLat: Double, userLon: Double, targetLat: Double, targetLon: Double) -> Float {
        let lat1 = userLat * .pi / 180
        let lat2 = targetLat * .pi / 180
        let dLon = (targetLon - userLon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return Float(atan2(y, x))
    }

    // MARK: - Coordinator

    class Coordinator {
        var arView: ARView?
        var lastPlacedLocation: CLLocation?
    }
}
