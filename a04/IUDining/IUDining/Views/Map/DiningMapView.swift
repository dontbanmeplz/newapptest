//
//  DiningMapView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI
import MapKit

/// Interactive map screen (second tab) showing all dining locations
/// as custom annotations on a MapKit map of the IU Bloomington campus.
///
/// Tapping an annotation opens a bottom sheet with the location's
/// full detail view. Supports user location display, compass, and
/// scale controls.
struct DiningMapView: View {
    /// Array of dining locations to display on the map.
    let locations: [DiningLocation]

    /// Camera position centered on the IU Bloomington campus.
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.1710, longitude: -86.5180),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

    /// The currently selected location for the detail sheet.
    @State private var selectedLocation: DiningLocation?

    var body: some View {
        NavigationStack {
            Map(position: $cameraPosition) {
                UserAnnotation()

                ForEach(locations.filter { $0.hasLocation }) { location in
                    Annotation(
                        location.name,
                        coordinate: location.coordinate,
                        anchor: .bottom
                    ) {
                        annotationView(for: location)
                            .onTapGesture {
                                selectedLocation = location
                            }
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedLocation) { location in
                NavigationStack {
                    LocationDetailView(location: location)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done") {
                                    selectedLocation = nil
                                }
                            }
                        }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Annotation View

    /// Creates a custom annotation view for a dining location with a
    /// fork-and-knife icon colored green (open) or red (closed).
    ///
    /// - Parameter location: The dining location to create an annotation for.
    /// - Returns: A view displaying the location's map annotation.
    private func annotationView(for location: DiningLocation) -> some View {
        VStack(spacing: 2) {
            Image(systemName: location.isOpen() ? "fork.knife.circle.fill" : "fork.knife.circle")
                .font(.title)
                .foregroundStyle(location.isOpen() ? .green : .red)
                .background(
                    Circle()
                        .fill(.white)
                        .frame(width: 28, height: 28)
                )

            Text(location.name)
                .font(.caption2)
                .fontWeight(.medium)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Hashable Conformance

/// Makes `DiningLocation` work with `.sheet(item:)` presentation.
extension DiningLocation: Hashable {
    static func == (lhs: DiningLocation, rhs: DiningLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
