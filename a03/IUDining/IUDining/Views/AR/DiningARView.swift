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
                        userLocation: locationService.userLocation,
                        heading: locationService.heading
                    )
                    .ignoresSafeArea()

                    // Overlay with location cards
                    VStack {
                        Spacer()
                        locationCarousel
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
            .padding(.bottom, 20)
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
    let heading: CLHeading?

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravityAndHeading // Align -Z to compass north
        arView.session.run(config)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Remove old markers
        arView.scene.anchors.removeAll()

        guard let userLoc = userLocation, let heading = heading else { return }

        for location in locations where location.hasLocation {
            let distance = Float(userLoc.distance(from: location.clLocation))

            // Skip locations further than 5km
            guard distance < 5000 else { continue }

            let bearing = bearingBetween(
                userLat: userLoc.coordinate.latitude,
                userLon: userLoc.coordinate.longitude,
                targetLat: location.coordinate.latitude,
                targetLon: location.coordinate.longitude
            )

            // Adjust bearing for device heading
            let headingRad = Float(heading.trueHeading * .pi / 180)
            let adjustedBearing = bearing - headingRad

            // Clamp distance for AR visibility (max 100m in AR space)
            let arDistance = min(distance, 100)

            // Convert polar to cartesian (ARKit: -Z is forward/north)
            let x = arDistance * sin(adjustedBearing)
            let z = -arDistance * cos(adjustedBearing)
            let y: Float = 0 // Eye level offset

            // Create marker entity
            let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))

            // Sphere marker
            let isOpen = location.isOpen()
            let color: UIColor = isOpen ? .systemGreen : .systemRed
            let sphere = ModelEntity(
                mesh: .generateSphere(radius: 0.5),
                materials: [SimpleMaterial(color: color, isMetallic: false)]
            )
            anchor.addChild(sphere)

            // Text label above sphere
            let textMesh = MeshResource.generateText(
                location.name,
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.15),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let textEntity = ModelEntity(
                mesh: textMesh,
                materials: [SimpleMaterial(color: .white, isMetallic: false)]
            )
            textEntity.position = SIMD3<Float>(0, 0.8, 0)

            // Center the text
            let textBounds = textEntity.visualBounds(relativeTo: nil)
            let textWidth = textBounds.extents.x
            textEntity.position.x = -textWidth / 2

            anchor.addChild(textEntity)

            // Distance label
            let distStr = String(format: "%.0fm", distance)
            let distMesh = MeshResource.generateText(
                distStr,
                extrusionDepth: 0.01,
                font: .systemFont(ofSize: 0.1),
                containerFrame: .zero,
                alignment: .center,
                lineBreakMode: .byTruncatingTail
            )
            let distEntity = ModelEntity(
                mesh: distMesh,
                materials: [SimpleMaterial(color: .lightGray, isMetallic: false)]
            )
            distEntity.position = SIMD3<Float>(0, 0.6, 0)
            let distBounds = distEntity.visualBounds(relativeTo: nil)
            distEntity.position.x = -distBounds.extents.x / 2

            anchor.addChild(distEntity)

            arView.scene.addAnchor(anchor)
        }
    }

    /// Calculate bearing between two GPS coordinates (returns radians)
    private func bearingBetween(userLat: Double, userLon: Double, targetLat: Double, targetLon: Double) -> Float {
        let lat1 = userLat * .pi / 180
        let lat2 = targetLat * .pi / 180
        let dLon = (targetLon - userLon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return Float(atan2(y, x))
    }
}
