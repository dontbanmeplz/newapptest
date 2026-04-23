//
//  DiningMapView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI
import MapKit

struct DiningMapView: View {
    let locations: [DiningLocation]

    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.1710, longitude: -86.5180),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        )
    )

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

// Make DiningLocation work with .sheet(item:)
extension DiningLocation: Hashable {
    static func == (lhs: DiningLocation, rhs: DiningLocation) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
