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
import MapKit

// MARK: - Main AR View

struct DiningARView: View {
    let locations: [DiningLocation]

    @State private var locationService = LocationService.shared
    @State private var selectedLocationID: Int?
    @State private var isCalibrating = true
    @State private var navigateToLocation: DiningLocation?

    var body: some View {
        NavigationStack {
            ZStack {
                if ARWorldTrackingConfiguration.isSupported {
                    ARViewContainer(
                        locations: locations,
                        userLocation: locationService.userLocation,
                        currentHeading: locationService.heading,
                        selectedLocationID: $selectedLocationID,
                        isCalibrating: $isCalibrating,
                        onLocationTapped: { location in
                            navigateToLocation = location
                        }
                    )
                    .ignoresSafeArea(.container, edges: .top)

                    // Calibrating overlay
                    if isCalibrating {
                        calibratingOverlay
                            .transition(.opacity)
                    }

                    // Bottom carousel overlay
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
            .animation(.easeInOut(duration: 0.3), value: isCalibrating)
            .navigationTitle("AR View")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .tabBar)
            .onAppear {
                locationService.startHeading()
            }
            .onDisappear {
                locationService.stopUpdating()
                locationService.startUpdating()
            }
            .navigationDestination(item: $navigateToLocation) { location in
                LocationDetailView(location: location)
            }
        }
    }

    // MARK: - Calibrating Overlay

    private var calibratingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.white)

            Text("Calibrating Compass")
                .font(.headline)
                .foregroundStyle(.white)

            Text("Move your phone in a figure-8 pattern")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(32)
        .background(.ultraThinMaterial.opacity(0.9))
        .background(Color.black.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Location Carousel

    private var locationCarousel: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(nearestLocations) { location in
                        carouselCard(for: location)
                            .id(location.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    selectedLocationID = location.id
                                }
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
            .onChange(of: selectedLocationID) { _, newID in
                if let newID {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newID, anchor: .center)
                    }
                }
            }
        }
    }

    private func carouselCard(for location: DiningLocation) -> some View {
        let isSelected = selectedLocationID == location.id
        let isOpen = location.isOpen()

        return VStack(alignment: .leading, spacing: 6) {
            // Name + status row
            HStack(spacing: 6) {
                Circle()
                    .fill(isOpen ? Color.green : Color.red)
                    .frame(width: 7, height: 7)

                Text(location.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.white)
            }

            // Distance
            Text(location.distanceString(from: locationService.userLocation))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))

            // Next transition
            if let transition = location.nextTransition() {
                Text("\(transition.label) at \(transition.time, style: .time)")
                    .font(.system(size: 9))
                    .foregroundStyle(isOpen ? Color.green.opacity(0.8) : Color.orange.opacity(0.8))
            }

            // Actions row
            HStack(spacing: 12) {
                Button {
                    navigateToLocation = location
                } label: {
                    Label("Menu", systemImage: "menucard")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }

                Button {
                    openDirections(to: location)
                } label: {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.25))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(
                            isSelected
                                ? (isOpen ? Color.green.opacity(0.8) : Color.red.opacity(0.8))
                                : Color.white.opacity(0.15),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                }
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }

    // MARK: - Helpers

    private var nearestLocations: [DiningLocation] {
        guard let userLoc = locationService.userLocation else {
            return Array(locations.filter(\.hasLocation).prefix(8))
        }
        return locations
            .filter { $0.hasLocation }
            .sorted { $0.distance(from: userLoc) < $1.distance(from: userLoc) }
    }

    private func openDirections(to location: DiningLocation) {
        let placemark = MKPlacemark(coordinate: location.coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

// MARK: - AR View Container (UIViewRepresentable)

struct ARViewContainer: UIViewRepresentable {
    let locations: [DiningLocation]
    let userLocation: CLLocation?
    let currentHeading: CLHeading?
    @Binding var selectedLocationID: Int?
    @Binding var isCalibrating: Bool
    let onLocationTapped: (DiningLocation) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        arView.environment.background = .cameraFeed()

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = .gravity
        arView.session.run(config)

        // Capture heading at session start
        if let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
            DispatchQueue.main.async { isCalibrating = false }
        }

        context.coordinator.arView = arView

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        arView.addGestureRecognizer(tapGesture)

        return arView
    }

    func updateUIView(_ arView: ARView, context: Context) {
        // Capture heading if we still need it
        if context.coordinator.initialHeading == nil,
           let heading = currentHeading, heading.trueHeading >= 0 {
            context.coordinator.initialHeading = Float(heading.trueHeading)
            DispatchQueue.main.async { isCalibrating = false }
        }

        guard let userLoc = userLocation,
              context.coordinator.initialHeading != nil else { return }

        // Only rebuild markers if user moved >15m or first time
        if let lastLoc = context.coordinator.lastPlacedLocation {
            let moved = userLoc.distance(from: lastLoc)
            if moved < 15 {
                // Even if not rebuilding, update selection highlight
                updateSelectionHighlight(in: arView, coordinator: context.coordinator)
                return
            }
        }

        context.coordinator.lastPlacedLocation = userLoc
        placeMarkers(in: arView, userLocation: userLoc, coordinator: context.coordinator)
    }

    // MARK: - Selection Highlight

    private func updateSelectionHighlight(in arView: ARView, coordinator: Coordinator) {
        for (locationID, anchorEntity) in coordinator.markerAnchors {
            let isSelected = locationID == selectedLocationID
            let targetScale: Float = isSelected ? 1.15 : 1.0

            if anchorEntity.scale.x != targetScale {
                // Animate scale
                var transform = anchorEntity.transform
                transform.scale = SIMD3<Float>(repeating: targetScale)
                anchorEntity.move(to: transform, relativeTo: anchorEntity.parent, duration: 0.25)
            }
        }
    }

    // MARK: - Marker Placement

    private func placeMarkers(in arView: ARView, userLocation: CLLocation, coordinator: Coordinator) {
        guard let initialHeadingDeg = coordinator.initialHeading else { return }
        let initialHeadingRad = initialHeadingDeg * .pi / 180

        // --- Pass 1: Compute marker data ---

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

        markers.sort { $0.arBearing < $1.arBearing }

        // --- Pass 2: Cluster detection and de-overlap ---

        let clusterThreshold: Float = 0.26
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

        let verticalSpacing: Float = 0.9
        let bearingNudge: Float = 0.04

        for cluster in clusters {
            let count = cluster.count
            let midpoint = Float(count - 1) / 2.0
            let sortedByDist = cluster.sorted { markers[$0].realDistance < markers[$1].realDistance }

            for (slot, idx) in sortedByDist.enumerated() {
                markers[idx].yOffset = (Float(slot) - midpoint) * verticalSpacing
                markers[idx].arBearing += (Float(slot) - midpoint) * bearingNudge
            }
        }

        // --- Pass 3: Diff-based placement ---

        let newIDs = Set(markers.map { $0.location.id })
        let existingIDs = Set(coordinator.markerAnchors.keys)

        // Remove stale markers with fade-out
        for id in existingIDs.subtracting(newIDs) {
            if let anchor = coordinator.markerAnchors.removeValue(forKey: id) {
                fadeOutAndRemove(anchor, from: arView)
            }
            coordinator.locationMap.removeValue(forKey: id)
        }

        // Add/update markers
        for marker in markers {
            let x = marker.arDistance * sin(marker.arBearing)
            let z = -marker.arDistance * cos(marker.arBearing)
            let y: Float = 0.8 + marker.yOffset

            let faceUserAngle = atan2(-x, -z)
            let targetOrientation = simd_quatf(angle: faceUserAngle, axis: SIMD3<Float>(0, 1, 0))
            let targetPosition = SIMD3<Float>(x, y, z)

            let isSelected = marker.location.id == selectedLocationID
            let scale: Float = isSelected ? 1.15 : 1.0

            if let existingAnchor = coordinator.markerAnchors[marker.location.id] {
                // Update existing -- smooth move
                var transform = Transform()
                transform.translation = targetPosition
                transform.rotation = targetOrientation
                transform.scale = SIMD3<Float>(repeating: scale)
                existingAnchor.move(to: transform, relativeTo: nil, duration: 0.5)
            } else {
                // New marker -- create with fade-in
                let anchor = AnchorEntity(world: targetPosition)
                anchor.orientation = targetOrientation
                anchor.scale = SIMD3<Float>(repeating: scale)
                anchor.name = "marker_\(marker.location.id)"

                buildTextureBillboard(
                    on: anchor,
                    location: marker.location,
                    realDistance: marker.realDistance,
                    userLocation: userLocation
                )

                // Start invisible, fade in
                anchor.scale = SIMD3<Float>(repeating: 0.01)
                arView.scene.addAnchor(anchor)

                var finalTransform = anchor.transform
                finalTransform.scale = SIMD3<Float>(repeating: scale)
                anchor.move(to: finalTransform, relativeTo: nil, duration: 0.4, timingFunction: .easeOut)

                coordinator.markerAnchors[marker.location.id] = anchor
                coordinator.locationMap[marker.location.id] = marker.location
            }
        }
    }

    // MARK: - Fade Out and Remove

    private func fadeOutAndRemove(_ anchor: AnchorEntity, from arView: ARView) {
        var transform = anchor.transform
        transform.scale = SIMD3<Float>(repeating: 0.01)
        anchor.move(to: transform, relativeTo: nil, duration: 0.3, timingFunction: .easeIn)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            arView.scene.removeAnchor(anchor)
        }
    }

    // MARK: - Texture Billboard Builder

    private func buildTextureBillboard(
        on anchor: AnchorEntity,
        location: DiningLocation,
        realDistance: Float,
        userLocation: CLLocation
    ) {
        let isOpen = location.isOpen()
        let transition = location.nextTransition()

        // Render the card to a UIImage
        let cardImage = renderCardImage(
            name: location.name,
            distance: location.distanceString(from: userLocation),
            isOpen: isOpen,
            transitionLabel: transition.map { "\($0.label)s \(Self.formatTransitionTime($0.time))" },
            width: 420,
            height: 200
        )

        // Billboard dimensions in meters
        let billboardWidth: Float = 0.8
        let billboardHeight: Float = billboardWidth * (200.0 / 420.0)

        let planeMesh = MeshResource.generatePlane(width: billboardWidth, height: billboardHeight)

        // Create texture from image
        guard let cgImage = cardImage.cgImage,
              let texture = try? TextureResource(image: cgImage, options: .init(semantic: .color)) else {
            return
        }

        var material = UnlitMaterial()
        material.color = .init(tint: .white, texture: .init(texture))
        material.opacityThreshold = 0.05

        let billboardEntity = ModelEntity(mesh: planeMesh, materials: [material])
        billboardEntity.name = "billboard_\(location.id)"

        anchor.addChild(billboardEntity)
    }

    // MARK: - Card Rendering (UIKit -> UIImage)

    private func renderCardImage(
        name: String,
        distance: String,
        isOpen: Bool,
        transitionLabel: String?,
        width: CGFloat,
        height: CGFloat
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { ctx in
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            let cgCtx = ctx.cgContext

            // -- Background: dark translucent with gradient --
            let cornerRadius: CGFloat = 20
            let bgPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
            cgCtx.saveGState()
            bgPath.addClip()

            // Dark gradient background
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bgColors: [CGColor] = [
                UIColor(white: 0.08, alpha: 0.92).cgColor,
                UIColor(white: 0.12, alpha: 0.88).cgColor,
            ]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: bgColors as CFArray, locations: [0, 1]) {
                cgCtx.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: 0, y: 0),
                    end: CGPoint(x: 0, y: height),
                    options: []
                )
            }

            // Subtle border
            cgCtx.setStrokeColor(UIColor(white: 1.0, alpha: 0.12).cgColor)
            cgCtx.setLineWidth(1.5)
            let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: cornerRadius)
            borderPath.stroke()

            cgCtx.restoreGState()

            // -- Accent bar on left edge --
            let accentColor: UIColor = isOpen
                ? UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 1.0)
                : UIColor(red: 0.95, green: 0.3, blue: 0.3, alpha: 1.0)

            let accentRect = CGRect(x: 0, y: 20, width: 4, height: height - 40)
            let accentPath = UIBezierPath(roundedRect: accentRect, cornerRadius: 2)
            accentColor.setFill()
            accentPath.fill()

            // -- Status dot --
            let dotRect = CGRect(x: 24, y: 26, width: 12, height: 12)
            let dotPath = UIBezierPath(ovalIn: dotRect)
            accentColor.setFill()
            dotPath.fill()

            // Dot glow
            cgCtx.saveGState()
            cgCtx.setShadow(offset: .zero, blur: 6, color: accentColor.withAlphaComponent(0.6).cgColor)
            dotPath.fill()
            cgCtx.restoreGState()

            // -- Status text next to dot --
            let statusText = isOpen ? "Open" : "Closed"
            let statusAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14, weight: .semibold),
                .foregroundColor: accentColor
            ]
            let statusStr = NSAttributedString(string: statusText, attributes: statusAttrs)
            statusStr.draw(at: CGPoint(x: 42, y: 23))

            // -- Name --
            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let nameStr = NSAttributedString(string: name, attributes: nameAttrs)
            let nameRect = CGRect(x: 24, y: 50, width: width - 48, height: 40)
            nameStr.draw(in: nameRect)

            // -- Distance --
            let distAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18, weight: .medium),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.55)
            ]
            let distStr = NSAttributedString(string: distance, attributes: distAttrs)
            distStr.draw(at: CGPoint(x: 24, y: 100))

            // -- Transition info --
            if let transitionLabel {
                let transAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 15, weight: .medium),
                    .foregroundColor: isOpen
                        ? UIColor(red: 0.3, green: 0.85, blue: 0.4, alpha: 0.7)
                        : UIColor(red: 1.0, green: 0.7, blue: 0.3, alpha: 0.7)
                ]
                let transStr = NSAttributedString(string: transitionLabel, attributes: transAttrs)
                transStr.draw(at: CGPoint(x: 24, y: 128))
            }

            // -- Direction arrow (chevron.right) in bottom-right --
            let arrowAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .semibold),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.3)
            ]
            let arrowStr = NSAttributedString(string: "\u{203A}", attributes: arrowAttrs)
            arrowStr.draw(at: CGPoint(x: width - 36, y: height / 2 - 16))

            // -- Tap hint at bottom --
            let hintAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: UIColor(white: 1.0, alpha: 0.25)
            ]
            let hintStr = NSAttributedString(string: "Tap for details", attributes: hintAttrs)
            hintStr.draw(at: CGPoint(x: 24, y: height - 30))
        }
    }

    // MARK: - Bearing Calculation

    private func bearingBetween(userLat: Double, userLon: Double, targetLat: Double, targetLon: Double) -> Float {
        let lat1 = userLat * .pi / 180
        let lat2 = targetLat * .pi / 180
        let dLon = (targetLon - userLon) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)

        return Float(atan2(y, x))
    }

    // MARK: - Time Formatting Helper

    private static func formatTransitionTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject {
        let parent: ARViewContainer
        var arView: ARView?
        var lastPlacedLocation: CLLocation?
        var initialHeading: Float?

        // Track markers by location ID for diff-based updates
        var markerAnchors: [Int: AnchorEntity] = [:]
        // Map location IDs to location objects for tap handling
        var locationMap: [Int: DiningLocation] = [:]

        init(parent: ARViewContainer) {
            self.parent = parent
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let arView else { return }
            let tapLocation = gesture.location(in: arView)

            // Hit test against entities
            let results = arView.hitTest(tapLocation)

            for result in results {
                // Walk up the entity hierarchy to find the anchor
                var entity: Entity? = result.entity
                while let current = entity {
                    if let name = current.name as String?,
                       name.hasPrefix("marker_") || name.hasPrefix("billboard_") {
                        let prefix = name.hasPrefix("marker_") ? "marker_" : "billboard_"
                        if let idStr = name.components(separatedBy: prefix).last,
                           let locationID = Int(idStr) {
                            // Found the tapped location
                            DispatchQueue.main.async { [weak self] in
                                guard let self else { return }
                                self.parent.selectedLocationID = locationID

                                // Double-tap detection: if already selected, navigate
                                if let location = self.locationMap[locationID] {
                                    // Brief delay to show selection, then navigate
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                        self.parent.onLocationTapped(location)
                                    }
                                }
                            }
                            return
                        }
                    }
                    entity = current.parent
                }
            }
        }
    }
}
