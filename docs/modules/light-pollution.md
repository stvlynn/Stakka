# Light Pollution Module

The light pollution module helps users find dark sky observation sites. It combines MapKit integration with location-based pollution level data.

## Files

```
Domains/DarkSky/
├── Presentation/
│   ├── DarkSkyMapView.swift
│   ├── DarkSkyViewModel.swift
│   └── Components/
│       └── DarkSkyInfoCard.swift
├── Application/
│   ├── CenterOnUserLocationUseCase.swift
│   └── FetchPollutionAtLocationUseCase.swift
├── Domain/
│   ├── BortleLevel.swift
│   ├── DarkSkyRepository.swift
│   └── LightPollution.swift
└── Infrastructure/
    ├── Location/
    │   └── CoreLocationService.swift
    └── Remote/
        └── MockDarkSkyRepository.swift
```

## Components

### LightPollutionMapView

Root view. Full-screen MapKit map with an optional info card overlay.

```swift
struct LightPollutionMapView: View {
    @State private var position: MapCameraPosition = .automatic
    @State private var selectedLocation: CLLocationCoordinate2D?
}
```

**Layout:**
```
ZStack
├── Map(position: $position)          ← full screen
│   └── Marker (when selected)
└── VStack
    └── Spacer
    └── LightPollutionInfoCard        ← slides up on selection
```

### LightPollutionInfoCard

Floating card that appears when a location is selected.

```
┌────────────────────────────────────┐
│  [✨]  光污染等级         [●]       │  ← sparkles + level dot
│  ─────────────────────────────── │
│  [↑]               [⟲]           │
│  34.0520°           118.2437°     │  ← lat / lon with icon
│                                   │
│  [🌙] 优秀暗空                    │  ← quality summary
└────────────────────────────────────┘
```

Icons replace text labels for latitude/longitude (no "Latitude:" prefix).
Quality text replaces verbose "Quality: Excellent Dark Sky" with "🌙 优秀暗空".

## Map Configuration

```swift
Map(position: $position) {
    if let location = selectedLocation {
        Marker("Selected", coordinate: location)
            .tint(Color.cosmicBlue)
    }
}
.mapStyle(.standard(elevation: .realistic))
.preferredColorScheme(.dark)
```

## Pollution Level System

Light pollution uses the Bortle scale (9 levels):

| Level | Description (EN)          | Description (ZH) | Color Indicator |
|-------|---------------------------|------------------|-----------------|
| 1     | Excellent dark sky        | 优秀暗空          | Green           |
| 2     | Typical truly dark site   | 极佳暗空          | Lime            |
| 3     | Rural sky                 | 乡村暗空          | Yellow-green    |
| 4     | Rural/suburban transition | 城郊过渡区        | Yellow          |
| 5     | Suburban sky              | 城郊天空          | Orange-yellow   |
| 6     | Bright suburban sky       | 明亮城郊          | Orange          |
| 7     | Suburban/urban transition | 近城区            | Red-orange      |
| 8     | City sky                  | 城市天空          | Red             |
| 9     | Inner-city sky            | 市中心            | Deep red        |

Current implementation shows mock data (Level 1). The pollution level indicator circle in the card header changes color based on level.

## Transition Animation

Info card slides up with combined transition:

```swift
.transition(.move(edge: .bottom).combined(with: .opacity))
```

Wrapped in `withAnimation(AnimationPreset.spring)` on location selection.

## Navigation

- Title: "光污染地图"
- `.ultraThinMaterial` navigation bar
- Location button (⊙) in top trailing — currently placeholder

## Current State

The module uses mock data. Real implementation needs:

1. Light pollution data source (API or offline dataset)
2. Location permission flow
3. Reverse geocoding for place names
4. Bortle scale classification from pollution values

## Data Integration Path

Recommended approach for real data:

```
1. Use Core Location for device position
2. Query light pollution API (e.g. lightpollutionmap.info API)
3. Parse pollution value → Bortle level
4. Update marker color + card content
5. Cache results locally for offline use
```

Reference: [Light Pollution Map repository](https://github.com/cgettings/Light-Pollution-Map)

## Toolbar

```swift
ToolbarItem(placement: .primaryAction) {
    Button {
        // TODO: Center on user location
    } label: {
        Image(systemName: "location.fill")
            .foregroundStyle(Color.cosmicBlue)
    }
}
```

## Future Work

- Real light pollution data integration
- Location permission request flow
- Persistent favorite locations
- Weather data overlay (cloud cover, seeing conditions)
- Nearby dark site suggestions
- Share location functionality
- Bortle scale legend overlay
- Historical pollution trend data
