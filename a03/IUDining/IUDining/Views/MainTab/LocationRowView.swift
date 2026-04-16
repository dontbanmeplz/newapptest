//
//  LocationRowView.swift
//  IUDining
//
//  Created by Christopher Sawicz on 4/16/26.
//

import SwiftUI
import CoreLocation

struct LocationRowView: View {
    let location: DiningLocation
    let userLocation: CLLocation?

    private var isOpen: Bool {
        location.isOpen()
    }

    private var transition: (label: String, time: Date)? {
        location.nextTransition()
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(isOpen ? Color.green : Color.red)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(location.name)
                        .font(.headline)

                    if location.isCafe {
                        Text("Cafe")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 8) {
                    Text(isOpen ? "Open" : "Closed")
                        .font(.subheadline)
                        .foregroundStyle(isOpen ? .green : .red)
                        .fontWeight(.medium)

                    if let transition {
                        Text("\(transition.label) \(transition.time, style: .time)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                if !location.distanceString(from: userLocation).isEmpty {
                    Label(location.distanceString(from: userLocation), systemImage: "location")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}
