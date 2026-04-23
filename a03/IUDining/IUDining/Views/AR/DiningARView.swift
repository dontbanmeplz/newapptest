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
import Combine

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
    let currentHeading: CLHeading?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)

        // Use AROrientationTrackingConfiguration (3DOF: rotation only)
        // Camera stays at the origin — billboards naturally stay around the user
        // We only need rotation tracking to show the correct direction
        let config = AROrientationTrackingConfiguration()
        config.worldAlignment = .gravity
        arView.session.run(config)

        // Capture the device heading at the moment the AR session starts
        // This tells us which compass direction -Z corresponds to
        if let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
        }

        context.coordinator.arView = arView

        // Subscribe to per-frame scene updates to keep billboards facing the camera
        context.coordinator.sceneSubscription = arView.scene.subscribe(
            to: SceneEvents.Update.self
        ) { [weak arView] _ in
            guard let arView = arView else { return }
            let cameraTransform = arView.cameraTransform
            let cameraPos = cameraTransform.translation

            for entry in context.coordinator.billboardEntries {
                let anchor = entry.anchor
                let pos = anchor.position
                let dx = cameraPos.x - pos.x
                let dz = cameraPos.z - pos.z
                let faceAngle = atan2(dx, dz)
                anchor.orientation = simd_quatf(angle: faceAngle, axis: SIMD3<Float>(0, 1, 0))
            }
        }

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // If we didn't get a heading at session start, capture it now
        if context.coordinator.initialHeading == nil,
           let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
        }

        guard let userLoc = userLocation,
              context.coordinator.initialHeading != nil else { return }

        // Rebuild markers when GPS updates (LocationService.distanceFilter handles throttling)
        // Skip if the location hasn't meaningfully changed
        if let lastLoc = context.coordinator.lastPlacedLocation {
            let moved = userLoc.distance(from: lastLoc)
            if moved < 5 { return }
        }

        context.coordinator.lastPlacedLocation = userLoc
        context.coordinator.currentUserLocation = userLoc
        placeMarkers(in: arView, userLocation: userLoc, coordinator: context.coordinator)
    }

    private func placeMarkers(in arView: ARView, userLocation: CLLocation, coordinator: Coordinator) {
        // Remove old markers
        for entry in coordinator.billboardEntries {
            arView.scene.removeAnchor(entry.anchor)
        }
        coordinator.billboardEntries.removeAll()

        // initialHeading is the compass direction (degrees) that -Z pointed at session start
        guard let initialHeadingDeg = coordinator.initialHeading else { return }
        let initialHeadingRad = initialHeadingDeg * .pi / 180

        // --- Pass 1: Compute positions for all markers ---

        struct MarkerData {
            let location: DiningLocation
            let realDistance: Float
            var arBearing: Float   // may be adjusted for cluster separation
            var arDistance: Float
            var yOffset: Float     // vertical stagger within cluster
        }

        var markers: [MarkerData] = []

        for location in locations where location.hasLocation {
            let realDistance = Float(userLocation.distance(from: location.clLocation))
            guard realDistance < 5000 else { continue }

            // Recalculate bearing from current GPS position to destination
            let gpsBearing = bearingBetween(
                userLat: userLocation.coordinate.latitude,
                userLon: userLocation.coordinate.longitude,
                targetLat: location.coordinate.latitude,
                targetLon: location.coordinate.longitude
            )

            let arBearing = gpsBearing - initialHeadingRad
            let arDistance: Float = 5.0 + min(realDistance / 1000.0, 1.0) * 3.0

            markers.append(MarkerData(
                location: location,
                realDistance: realDistance,
                arBearing: arBearing,
                arDistance: arDistance,
                yOffset: 0
            ))
        }

        // Sort by bearing so we can detect angular neighbors
        markers.sort { $0.arBearing < $1.arBearing }

        // --- Pass 2: Detect clusters and spread them apart ---
        // Two markers overlap if their bearings are within ~15 degrees (~0.26 rad)
        let clusterThreshold: Float = 0.26

        // Group into clusters of angularly-close markers
        var clusters: [[Int]] = []  // array of index groups
        var visited = Set<Int>()

        for i in markers.indices where !visited.contains(i) {
            var cluster = [i]
            visited.insert(i)

            for j in (i + 1)..<markers.count {
                if visited.contains(j) { continue }

                // Check angular distance (handle wraparound)
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

        // For each cluster, stagger vertically and nudge bearing slightly
        let verticalSpacing: Float = 1.0    // 1m between stacked cards
        let bearingNudge: Float = 0.04       // ~2.3 degrees horizontal nudge

        for cluster in clusters {
            let count = cluster.count
            let midpoint = Float(count - 1) / 2.0

            // Sort cluster members by real distance (closest at center/bottom)
            let sortedByDist = cluster.sorted { markers[$0].realDistance < markers[$1].realDistance }

            for (slot, idx) in sortedByDist.enumerated() {
                // Vertical stagger: centered around y=1.0
                let verticalOffset = (Float(slot) - midpoint) * verticalSpacing
                markers[idx].yOffset = verticalOffset

                // Horizontal nudge: spread bearing slightly
                let horizontalOffset = (Float(slot) - midpoint) * bearingNudge
                markers[idx].arBearing += horizontalOffset
            }
        }

        // --- Pass 3: Place markers in the scene ---
        // With orientation-only tracking, camera stays at origin.
        // Billboards are placed around the origin and naturally stay around the user.

        for marker in markers {
            let x = marker.arDistance * sin(marker.arBearing)
            let z = -marker.arDistance * cos(marker.arBearing)
            let y: Float = 1.0 + marker.yOffset

            let anchor = AnchorEntity(world: SIMD3<Float>(x, y, z))

            // Initial face-camera rotation (camera is at origin)
            let faceUserAngle = atan2(-x, -z)
            anchor.orientation = simd_quatf(angle: faceUserAngle, axis: SIMD3<Float>(0, 1, 0))

            // Build the billboard card
            buildBillboard(on: anchor, location: marker.location, realDistance: marker.realDistance)

            arView.scene.addAnchor(anchor)

            // Store reference for per-frame face-camera updates
            coordinator.billboardEntries.append(BillboardEntry(
                location: marker.location,
                anchor: anchor,
                yOffset: marker.yOffset,
                bearingNudge: 0
            ))
        }
    }

    /// Builds the billboard card entities and attaches them to the anchor
    private func buildBillboard(on anchor: AnchorEntity, location: DiningLocation, realDistance: Float) {
        let isOpen = location.isOpen()
        let panelColor: UIColor = isOpen
            ? UIColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.88)
            : UIColor(red: 0.6, green: 0.1, blue: 0.1, alpha: 0.88)

        // Name text
        let nameMesh = MeshResource.generateText(
            location.name,
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

        // Measure text to size the panel
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

        // Position text in front of panel (local +Z faces the user)
        let frontZ: Float = panelDepth / 2 + 0.005

        nameEntity.position = SIMD3<Float>(
            -nameBounds.extents.x / 2,
            0.12,
            frontZ
        )
        anchor.addChild(nameEntity)

        distEntity.position = SIMD3<Float>(
            -distBounds.extents.x / 2,
            -0.05,
            frontZ
        )
        anchor.addChild(distEntity)

        statusEntity.position = SIMD3<Float>(
            -statusBounds.extents.x / 2,
            -0.22,
            frontZ
        )
        anchor.addChild(statusEntity)

        // Status dot at top-left
        let dot = ModelEntity(
            mesh: .generateSphere(radius: 0.06),
            materials: [SimpleMaterial(color: isOpen ? .systemGreen : .systemRed, isMetallic: false)]
        )
        dot.position = SIMD3<Float>(-panelWidth / 2 + 0.1, 0.22, frontZ)
        anchor.addChild(dot)
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

    // MARK: - Billboard Entry

    /// Stores a reference to a placed billboard anchor and its associated data
    struct BillboardEntry {
        let location: DiningLocation
        let anchor: AnchorEntity
        let yOffset: Float
        let bearingNudge: Float
    }

    // MARK: - Coordinator

    class Coordinator {
        var arView: ARView?
        var lastPlacedLocation: CLLocation?
        var currentUserLocation: CLLocation?
        var initialHeading: Float? // Compass heading (degrees) at AR session start
        var billboardEntries: [BillboardEntry] = []
        var sceneSubscription: Cancellable?
    }
}
