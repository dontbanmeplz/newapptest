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

// MARK: - DiningARView (SwiftUI wrapper)

struct DiningARView: View {
    let locations: [DiningLocation]

    @State private var locationService = LocationService.shared
    @State private var arError: String?

    var body: some View {
        NavigationStack {
            ZStack {
                if AROrientationTrackingConfiguration.isSupported {
                    ARViewContainer(
                        locations: locations,
                        userLocation: locationService.userLocation,
                        currentHeading: locationService.heading
                    )
                    .ignoresSafeArea(.container, edges: .top)

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

// MARK: - ARViewContainer (UIViewRepresentable)

struct ARViewContainer: UIViewRepresentable {
    let locations: [DiningLocation]
    let userLocation: CLLocation?
    let currentHeading: CLHeading?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: makeUIView

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // 3DOF orientation-only tracking: the camera stays at the origin,
        // billboards are placed around it based on GPS bearing + distance.
        let config = AROrientationTrackingConfiguration()
        config.worldAlignment = .gravity
        arView.session.run(config)

        // Capture the compass heading at session start so we know
        // which real-world direction the AR -Z axis corresponds to.
        if let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
        }

        context.coordinator.arView = arView

        // No per-frame subscription needed: BillboardComponent handles
        // face-camera rotation automatically.

        return arView
    }

    // MARK: updateUIView

    func updateUIView(_ arView: ARView, context: Context) {
        // Capture heading if we missed it at session start
        if context.coordinator.initialHeading == nil,
           let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
        }

        guard let userLoc = userLocation,
              context.coordinator.initialHeading != nil else { return }

        // Only rebuild when the user has moved significantly (>5 m)
        if let lastLoc = context.coordinator.lastPlacedLocation {
            if userLoc.distance(from: lastLoc) < 5 { return }
        }

        context.coordinator.lastPlacedLocation = userLoc
        placeMarkers(in: arView, userLocation: userLoc, coordinator: context.coordinator)
    }

    // MARK: - Marker Placement

    private func placeMarkers(in arView: ARView, userLocation: CLLocation, coordinator: Coordinator) {
        // Clear previous billboards
        for entry in coordinator.billboardEntries {
            arView.scene.removeAnchor(entry.anchor)
        }
        coordinator.billboardEntries.removeAll()

        guard let initialHeadingDeg = coordinator.initialHeading else { return }
        let initialHeadingRad = initialHeadingDeg * .pi / 180

        // -- Pass 1: Build marker data from GPS --

        struct MarkerData {
            let location: DiningLocation
            let realDistance: Float
            var arBearing: Float
            var arDistance: Float
            var yOffset: Float
        }

        var markers: [MarkerData] = []

        for location in locations where location.hasLocation {
            let realDistance = Float(userLocation.distance(from: location.clLocation))
            guard realDistance < 5000 else { continue }

            let gpsBearing = bearingBetween(
                userLat: userLocation.coordinate.latitude,
                userLon: userLocation.coordinate.longitude,
                targetLat: location.coordinate.latitude,
                targetLon: location.coordinate.longitude
            )

            // Convert GPS bearing into AR-space bearing by subtracting
            // the compass heading that was captured at session start.
            let arBearing = gpsBearing - initialHeadingRad

            // Map real distance (0-1000+ m) to a comfortable AR range (5-8 m from origin)
            let arDistance: Float = 5.0 + min(realDistance / 1000.0, 1.0) * 3.0

            markers.append(MarkerData(
                location: location,
                realDistance: realDistance,
                arBearing: arBearing,
                arDistance: arDistance,
                yOffset: 0
            ))
        }

        markers.sort { $0.arBearing < $1.arBearing }

        // -- Pass 2: Detect angular clusters and spread them apart --

        let clusterThreshold: Float = 0.26  // ~15 degrees
        var clusters: [[Int]] = []
        var visited = Set<Int>()

        for i in markers.indices where !visited.contains(i) {
            var cluster = [i]
            visited.insert(i)

            for j in (i + 1)..<markers.count {
                if visited.contains(j) { continue }
                let diff = abs(markers[j].arBearing - markers[cluster.last!].arBearing)
                if diff < clusterThreshold {
                    cluster.append(j)
                    visited.insert(j)
                }
            }

            if cluster.count > 1 {
                clusters.append(cluster)
            }
        }

        let verticalSpacing: Float = 1.0
        let bearingNudge: Float = 0.04  // ~2.3 degrees

        for cluster in clusters {
            let midpoint = Float(cluster.count - 1) / 2.0
            let sortedByDist = cluster.sorted { markers[$0].realDistance < markers[$1].realDistance }

            for (slot, idx) in sortedByDist.enumerated() {
                markers[idx].yOffset = (Float(slot) - midpoint) * verticalSpacing
                markers[idx].arBearing += (Float(slot) - midpoint) * bearingNudge
            }
        }

        // -- Pass 3: Place billboards in the AR scene --

        for marker in markers {
            let x = marker.arDistance * sin(marker.arBearing)
            let z = -marker.arDistance * cos(marker.arBearing)
            let y: Float = 1.0 + marker.yOffset

            // Anchor holds the world-space position only (no rotation).
            let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))

            buildBillboard(on: anchor, location: marker.location, realDistance: marker.realDistance)

            arView.scene.addAnchor(anchor)

            coordinator.billboardEntries.append(BillboardEntry(
                location: marker.location,
                anchor: anchor,
                yOffset: marker.yOffset
            ))
        }
    }

    // MARK: - Billboard Construction

    /// Builds a billboard card and attaches it to the given anchor.
    /// All visual content lives inside a container entity that has
    /// `BillboardComponent` so it automatically faces the camera.
    private func buildBillboard(on anchor: AnchorEntity, location: DiningLocation, realDistance: Float) {
        let isOpen = location.isOpen()

        // Container entity that will auto-rotate to face the camera
        let container = Entity()
        container.components.set(BillboardComponent())
        anchor.addChild(container)

        // -- Panel colors --

        let panelColor: UIColor = isOpen
            ? UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.88)
            : UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.88)

        // -- Text entities --

        let nameEntity = makeTextEntity(
            location.name,
            font: .boldSystemFont(ofSize: 0.22),
            color: .white
        )

        let distStr: String
        if realDistance < 1000 {
            distStr = String(format: "%.0f m away", realDistance)
        } else {
            distStr = String(format: "%.1f mi away", realDistance / 1609.34)
        }
        let distEntity = makeTextEntity(
            distStr,
            font: .systemFont(ofSize: 0.14),
            color: UIColor(white: 0.9, alpha: 1.0)
        )

        let statusStr = isOpen ? "Open Now" : "Closed"
        let statusColor: UIColor = isOpen
            ? UIColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 1.0)
            : UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0)
        let statusEntity = makeTextEntity(
            statusStr,
            font: .boldSystemFont(ofSize: 0.12),
            color: statusColor
        )

        // -- Measure text to size the panel --

        let nameBounds = nameEntity.visualBounds(relativeTo: nil)
        let distBounds = distEntity.visualBounds(relativeTo: nil)
        let statusBounds = statusEntity.visualBounds(relativeTo: nil)

        let maxTextWidth = max(nameBounds.extents.x, max(distBounds.extents.x, statusBounds.extents.x))
        let panelWidth = maxTextWidth + 0.3
        let panelHeight: Float = 0.7
        let panelDepth: Float = 0.02

        // -- Background panel --

        let panelMesh = MeshResource.generateBox(
            size: SIMD3<Float>(panelWidth, panelHeight, panelDepth),
            cornerRadius: 0.05
        )
        let panelEntity = ModelEntity(
            mesh: panelMesh,
            materials: [SimpleMaterial(color: panelColor, isMetallic: false)]
        )
        container.addChild(panelEntity)

        // -- Position text in front of the panel --
        // generateText produces text readable from +Z.
        // BillboardComponent points the entity's +Z toward the camera.
        // So placing content at +Z puts it on the camera-facing side.

        let frontZ: Float = panelDepth / 2 + 0.005

        nameEntity.position = SIMD3<Float>(
            -nameBounds.extents.x / 2,
            0.12,
            frontZ
        )
        container.addChild(nameEntity)

        distEntity.position = SIMD3<Float>(
            -distBounds.extents.x / 2,
            -0.05,
            frontZ
        )
        container.addChild(distEntity)

        statusEntity.position = SIMD3<Float>(
            -statusBounds.extents.x / 2,
            -0.22,
            frontZ
        )
        container.addChild(statusEntity)

        // -- Status dot (top-left) --

        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.06),
            materials: [SimpleMaterial(color: isOpen ? .systemGreen : .systemRed, isMetallic: false)]
        )
        dot.position = SIMD3<Float>(-panelWidth / 2 + 0.1, 0.22, frontZ)
        container.addChild(dot)
    }

    /// Helper to create a 3D text entity with the given string, font, and color.
    private func makeTextEntity(_ text: String, font: UIFont, color: UIColor) -> ModelEntity {
        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: 0.005,
            font: font,
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byTruncatingTail
        )
        return ModelEntity(
            mesh: mesh,
            materials: [SimpleMaterial(color: color, isMetallic: false)]
        )
    }

    // MARK: - Bearing Calculation

    /// Calculates the bearing (in radians) from one GPS coordinate to another.
    /// 0 = north, positive = clockwise.
    private func bearingBetween(
        userLat: Double, userLon: Double,
        targetLat: Double, targetLon: Double
    ) -> Float {
        let lat1 = userLat * .pi / 180
        let lat2 = targetLat * .pi / 180
        let dLon = (targetLon - userLon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return Float(atan2(y, x))
    }

    // MARK: - Supporting Types

    struct BillboardEntry {
        let location: DiningLocation
        let anchor: AnchorEntity
        let yOffset: Float
    }

    class Coordinator {
        var arView: ARView?
        var lastPlacedLocation: CLLocation?
        var initialHeading: Float?
        var billboardEntries: [BillboardEntry] = []
    }
}
