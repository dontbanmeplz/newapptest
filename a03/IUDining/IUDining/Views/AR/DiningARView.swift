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
            // No heading adjustment needed -- ARKit handles compass alignment
            // Clamp AR distance so markers are visible (max 80m in AR space)
            let arDistance = min(realDistance, 80)

            // Convert bearing + distance to cartesian
            // bearing=0 is north (-Z), bearing=pi/2 is east (+X)
            let x = arDistance * sin(bearing)
            let z = -arDistance * cos(bearing)
            let y: Float = 2.0 // Place at eye level / slightly above

            let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))

            // Scale sphere so it's always visible regardless of distance
            let sphereRadius = max(0.5, arDistance * 0.025)
            let isOpen = location.isOpen()
            let color: UIColor = isOpen ? .systemGreen : .systemRed

            let sphere = ModelEntity(
                mesh: .generateSphere(radius: sphereRadius),
                materials: [SimpleMaterial(color: color.withAlphaComponent(0.85), isMetallic: false)]
            )
            anchor.addChild(sphere)

            // Name label above sphere
            let fontSize: CGFloat = max(0.12, CGFloat(arDistance) * 0.003)
            let textMesh = MeshResource.generateText(
                location.name,
                extrusionDepth: 0.01,
                font: .boldSystemFont(ofSize: fontSize),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let textEntity = ModelEntity(
                mesh: textMesh,
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            // Position above sphere
            textEntity.position = SIMD3<Float>(0, sphereRadius + 0.3, 0)
            // Center horizontally
            let textBounds = textEntity.visualBounds(relativeTo: nil)
            textEntity.position.x = -textBounds.extents.x / 2

            anchor.addChild(textEntity)

            // Distance label below name
            let distStr: String
            if realDistance < 1000 {
                distStr = String(format: "%.0fm", realDistance)
            } else {
                distStr = String(format: "%.1f mi", realDistance / 1609.34)
            }

            let distFontSize: CGFloat = max(0.08, CGFloat(arDistance) * 0.002)
            let distMesh = MeshResource.generateText(
                distStr,
                extrusionDepth: 0.005,
                font: .systemFont(ofSize: distFontSize),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let distEntity = ModelEntity(
                mesh: distMesh,
                materials: [SimpleMaterial(color: .lightGray, isMetallic: false)]
            )
            distEntity.position = SIMD3<Float>(0, sphereRadius + 0.1, 0)
            let distBounds = distEntity.visualBounds(relativeTo: nil)
            distEntity.position.x = -distBounds.extents.x / 2

            anchor.addChild(distEntity)

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
