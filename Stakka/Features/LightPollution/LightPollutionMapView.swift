import SwiftUI
import MapKit

struct LightPollutionMapView: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedLocation: CLLocationCoordinate2D?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.spaceBackground
                    .ignoresSafeArea()

                Map(position: $position) {
                    if let location = selectedLocation {
                        Marker("Selected", coordinate: location)
                            .tint(Color.cosmicBlue)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .preferredColorScheme(.dark)

                VStack {
                    Spacer()
                    if let location = selectedLocation {
                        LightPollutionInfoCard(coordinate: location)
                            .padding(.horizontal, Spacing.md)
                            .padding(.bottom, Spacing.lg)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationTitle("光污染地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        // Center on user location
                    } label: {
                        Image(systemName: "location.fill")
                            .foregroundStyle(Color.cosmicBlue)
                    }
                }
            }
        }
    }
}

struct LightPollutionInfoCard: View {
    let coordinate: CLLocationCoordinate2D

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Color.cosmicBlue)
                    .font(.title3)
                    .breathingGlow(color: .cosmicBlue, radius: 4)

                Text("光污染等级")
                    .font(.stakkaHeadline)
                    .foregroundStyle(Color.starWhite)

                Spacer()

                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .glow(color: .green, radius: 4)
            }

            Divider().overlay(Color.spaceSurfaceElevated)

            HStack(spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "location.north.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Text("\(coordinate.latitude, specifier: "%.4f")°")
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.textTertiary)
                    Text("\(coordinate.longitude, specifier: "%.4f")°")
                        .font(.stakkaCaption)
                        .foregroundStyle(Color.textSecondary)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }

            HStack {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.green)
                Text("优秀暗空")
                    .font(.stakkaCaption)
                    .foregroundStyle(Color.green)
                    .fontWeight(.semibold)
            }
        }
        .padding(Spacing.md)
        .glassCard()
    }
}
